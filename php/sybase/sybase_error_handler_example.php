function send_to_dba () {
    // FIXME:
    throw new Exception("errno={$errno} errstr={$errstr} errfile={$errfile} errline={$errline}");
}

function myErrorHandler( $errno, $errstr, $errfile, $errline )
{
    // identify Sybase messages
    if(preg_match('/Sybase:\s*(.*?)\s*\(severity (\d+), procedure ([^)]+)\)/i',$errstr,$m)) {
        $sybase_msg = $m[1];
        $sybase_error_level = $m[2];
        $sybase_proc = $m[3];
        // shorten "Server message:"
        if(preg_match('/^\s*Server message:\s*(.*?)$/',$sybase_msg,$m)) {
            $sybase_msg = 'S '.$m[1];
        }
        $logmsg = "$errfile:$errline Sybase: sev={$sybase_error_level} proc={$sybase_proc} {$sybase_msg}";
        error_log($logmsg);

        // http://www.compuspec.net/reference/database/sybase/severity_levels.shtml
        if($sybase_error_level>=17)
            send_to_dba($logmsg);

        if($sybase_error_level > 10)
            throw new Exception($logmsg);

        return;
    }

    // non-Sybase Messages:
    $replevel = error_reporting();
    if( ( $errno & $replevel ) != $errno )
    {
        // we shall remain quiet.
        return;
    }
    error_log( "errno={$errno} errstr={$errstr} errfile={$errfile} errline={$errline}" );
}

set_error_handler('myErrorHandler');
