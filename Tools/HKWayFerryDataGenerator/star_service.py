"""Conservative fallback for Star Ferry's published English HTML tables."""

from html.parser import HTMLParser
import re
import html

from adapters import ROUTES, calendar, cents, direction, frequency, rule_key


class ServiceTables(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tables = []
        self.heading = ""
        self.section = ""
        self.heading_parts = None
        self.table = None
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag in {"h2", "h3", "h4", "h5"}:
            self.heading_parts = []
        if tag == "table" and self.table is None:
            self.table = []
        if self.table is not None and tag == "tr":
            self.row = []
        if self.row is not None and tag in {"th", "td"}:
            self.cell = []
        if tag == "br" and self.cell is not None:
            self.cell.append(" ")
        if tag == "sup" and self.cell is not None:
            self.cell.append(" [")

    def handle_data(self, data):
        if self.heading_parts is not None:
            self.heading_parts.append(data)
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag == "sup" and self.cell is not None:
            self.cell.append("]")
        if tag in {"h2", "h3", "h4", "h5"} and self.heading_parts is not None:
            self.heading = " ".join("".join(self.heading_parts).split())
            self.heading_parts = None
            heading = self.heading.lower().replace("wanchai", "wan chai")
            if "tsim sha tsui" in heading and (
                "central" in heading or "wan chai" in heading
            ):
                self.section = self.heading
        if tag in {"th", "td"} and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        if tag == "tr" and self.row is not None:
            self.table.append(self.row)
            self.row = None
        if tag == "table" and self.table is not None:
            self.tables.append((self.section, self.heading, self.table))
            self.table = None


def parse_service(route, body):
    a, b, *_ = ROUTES[route]
    parser = ServiceTables()
    parser.feed(body)
    timetables, fares = [], []
    categories = re.compile(r"^(Adult|Child|Disabled Person|Senior|Monthly Pass|Four-Day Tourist Pass|Bicycle)\b", re.I)
    for section, heading, table in parser.tables:
        section = section.lower().replace("wanchai", "wan chai")
        if a.lower() not in section or b.lower() not in section:
            continue
        tag, key = None, None
        confirmed_fare_header = (len(table) > 0 and len(table[0]) == 3 and not table[0][0]
                                 and heading.lower() == "fare table")
        if confirmed_fare_header:
            confirmed_fare_header = [rule_key(label) for label in table[0][1:]] == ["weekday", "weekendOrHoliday"]
            if route == "7030":
                confirmed_fare_header = confirmed_fare_header and len(table) > 1 and table[1] == [
                    "", "Upper Deck", "Lower Deck", "Upper Deck", "Lower Deck"]
        for row in [[heading], *table]:
            if not row:
                continue
            label = row[0]
            origin_match = re.fullmatch(r"Departures? from (.+)", label, re.I)
            if origin_match:
                origin = origin_match[1].strip().replace("Wanchai", "Wan Chai")
                dest = b if origin.casefold() == a.casefold() else a
                tag, key = direction(route, f"{origin} to {dest}"), None
            if tag and len(row) == 1:
                try:
                    key = rule_key(label)
                except ValueError:
                    pass
            if tag and len(row) == 2 and re.match(r"^\d{1,2}:\d{2}", label):
                if key is None:
                    raise ValueError("Star Ferry HTML period has no service-day heading")
                timetables.append(frequency(tag, key, label, row[1]))
            if (confirmed_fare_header and categories.match(label) and row[1:]
                and all(re.fullmatch(r"\$[\d.]+", v) for v in row[1:])):
                note_match = re.search(r"\s*\[(\d+)\]$", label)
                codes = [note_match[1]] if note_match else []
                if note_match:
                    label = label[:note_match.start()].strip()
                values = row[1:]
                if len(values) == 4 and route == "7030":
                    classes = ["upperDeck", "lowerDeck"] * 2
                    keys = ["weekday"] * 2 + ["weekendOrHoliday"] * 2
                elif len(values) == 2 and route == "7031":
                    classes, keys = [None, None], ["weekday", "weekendOrHoliday"]
                elif len(values) == 1 and re.match(r"Monthly Pass|Four-Day Tourist Pass|Bicycle", label, re.I):
                    classes, keys = [None], ["daily"]
                else:
                    raise ValueError(f"unexpected Star Ferry fare table layout for {route}")
                for value, fare_class, day_key in zip(values, classes, keys):
                    fares.append({"category": label, "amountMinor": cents(value), "currency": "HKD",
                                  "serviceDays": calendar(day_key), "fareClass": fare_class,
                                  "remarkCodes": codes})
    categories_found = {categories.match(item["category"])[1].lower() for item in fares}
    required = {"adult", "child", "disabled person", "senior", "monthly pass", "four-day tourist pass"}
    if not required <= categories_found:
        raise ValueError("official Star Ferry HTML fare categories missing or layout changed")
    page_notes = []
    for entry in re.findall(r"<li\b[^>]*>(.*?)</li>", body, re.I | re.S):
        note = " ".join(html.unescape(re.sub(r"<[^>]*>", " ", entry)).split())
        if note.lower().startswith(("if the height", "a disability registration", "hong kong resident",
                                     "monthly passes", "the four-day", "only the lower deck",
                                     "actual sailing times")):
            page_notes.append(note)
    if len(page_notes) < 5:
        raise ValueError("official Star Ferry restriction notes missing or layout changed")
    return timetables, fares, "\n".join(page_notes)
