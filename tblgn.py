# Box geometry.

class Box(object):
    def __init__(self, x, y, right, bottom):
        self.x, self.y, self.right, self.bottom = x, y, right, bottom

def box_x_delimeters(boxes):
    return sorted(set(box.right for box in boxes))

def box_y_delimiters(boxes):
    return sorted(set(box.bottom for box in boxes))

def box_rowspans(boxes):
    rowspans = dict((box, 0) for box in boxes)
    for delim in box_y_delimiters(boxes):
        for box in boxes:
            if box.y < delim and box.bottom >= delim:
                rowspans[box] += 1
    return rowspans

def box_colspans(boxes):
    colspans = dict((box, 0) for box in boxes)
    for delim in box_x_delimeters(boxes):
        for box in boxes:
            if box.x < delim and box.right >= delim:
                colspans[box] += 1
    return colspans

def box_rows(boxes):
    rows, boxes_left = [], set(boxes)
    for delim in box_y_delimiters(boxes):
        boxes_in_row = set(box for box in boxes_left if box.y < delim)
        boxes_left -= boxes_in_row
        rows.append(sorted(boxes_in_row, key=lambda box: box.x))
    return rows

# Rendering and parsing tables.

def render_html_table(boxes):
    rowspans, colspans = box_rowspans(boxes), box_colspans(boxes)
    table = '<table border="border">\n'
    for row in box_rows(boxes):
        table += '  <tr>\n'
        for box in row:
            table += '    <td rowspan="%d" colspan="%d">%s</td>\n' % (rowspans[box], colspans[box], 'blank<br/>' * (box.bottom - box.y))
        table += '  </tr>\n'
    table += '</table>\n'
    return table

def parse_ascii_table(table):
    def char(x, y):
        if 0 <= y < len(grid) and 0 <= x < len(grid[y]):
            return grid[y][x]
        else:
            return " "

    def box_right(x, y):
        for right in range(x, len(grid[y + 1])):
            if char(right + 1, y + 1) == '|':
                return right
        raise RuntimeError("Unterminated box.")
    
    def box_bottom(x, y):
        for bottom in range(y, len(grid)):
            if char(x + 1, bottom + 1) == '-':
                return bottom
        raise RuntimeError("Unterminated box.")

    grid = table.splitlines()
    boxes = []
    for y in range(len(grid)):
        for x in range(len(grid[y])):
            if char(x, y) in ('-', '|') and char(x, y + 1) == '|' and char(x + 1, y) == '-':
                boxes.append(Box(x, y, box_right(x, y), box_bottom(x, y)))
    return boxes

# Tests.

table = \
"""
-----------------------------------------------------------------------------
| adsafasf                            |                                     |
|                                     |                                     |
|                                     |                                     |
-----------------------------------------------------------------------------
|                                     |                                     |
|                                     |                                     |
|                                     |                                     |
-----------------------------------------------------------------------------
|                                     |                                     |
|                                     |                                     |
|                                     |                                     |
-----------------------------------------------------------------------------
"""

open("test.html", "w").write('<html>\n<body>\n%s</body>\n</html>\n' % (render_html_table(parse_ascii_table(table)),))

