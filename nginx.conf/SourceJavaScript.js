function kvFilter(req) {
    var v0, full_filter = "";
    for (v0 in req.args) {
        if (full_filter.length > 1) {
            full_filter += " AND";
        }

        if(v0 != 'undefined') {
            full_filter += " " + v0 + "='" + req.args[v0] + "'";
        }
    }

    if (full_filter.length > 0) {
        return " WHERE"+full_filter+"\n";
    }
}
