function GoodFilter(req) {
    var v0, value, data, full_filter = "";

    var regex_value = /([\d\w]*)/;
    var regex_data  = /[\d\w,._]*/; 
    for (v0 in req.args) {
        value = regex_value.exec(v0);

        if (full_filter.length > 1) {
            full_filter += " AND";
        }

        if(value != 'undefined') {
            data = regex_data.exec(req.args[v0]);
            full_filter += " " + value[1] + "='" + data + "'";
        }
    }

    if (full_filter.length > 0) {
        return " WHERE"+full_filter+"\n";
    }
}

function BadFilter(req) {
/* ALERT!!!
 * This sample without Regexp Character Class.
 * So it's dangerous for injection.
 */
    var v0, full_filter = "";
    for (v0 in req.args) {
        if (full_filter.length > 1) full_filter += " AND";

        if(v0 != 'undefined')
            full_filter += " " + v0 + "='" + req.args[v0] + "'";
    }

    if (full_filter.length > 0) return " WHERE"+full_filter+"\n";
}
