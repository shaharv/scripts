def isDefinedNotEmpty(arg) {
    // validating that arg is not null object and the value of arg is not empty or "null"
    return (arg == 0) || (arg && (arg != "null") && (arg != "") && ("${arg}" != "null"))
}

return this