#!/usr/bin/perl
use strict;

our @log_files_normal;
our @log_files_each_week;

@log_files_normal = ( 
   {'file_name' => '/var/log/rsync/ec_sync.log',    #required file name
    'reg_exp' =>'\.tpl', #required reg_exp
	'time' =>'START EC SYNC', #required reg_exp
	'rotate_check_file'=>'/var/log/rsync/ec_sync.tpl_logrotate_check.tmp',
   },
);


#前回実行時のログファイル先頭行と現在のログファイル先頭行に差異がある場合、logrotationがあったものとみなし、bkファイルのtplファイル検索も行う
#前回実行時と今回のログファイルの先頭行を比較する。
foreach my $cnf ( @log_files_normal ) {  #log_filesの設定を $cnf に代入する

#print $cnf->{'rotate_check_file'};
print "rotation check start!...\n##################################################\n";
	
	my $before_first_line='';
	our $this_first_line='';
	my $rotate_check_file_exists=-1;
	if (open(ROTATE_CHECK_FILE, $cnf->{'rotate_check_file'})) { #ファイル読み込んでSEEK_FILE変数に格納
		print "opened:$cnf->{'rotate_check_file'}...\n";		
		$rotate_check_file_exists=1;
		my @rotate_check_pos;
        chomp(@rotate_check_pos = <ROTATE_CHECK_FILE>); #改行削除
        #  If file is empty, no need to seek...
#print "before_first_line:$rotate_check_pos[0]\n";
#        if ($rotate_check_pos[0] != '') {
        	$before_first_line=$rotate_check_pos[0]."\n";
			print "前回先頭行：$before_first_line\n";
        close(ROTATE_CHECK_FILE);
        print "...closed:$cnf->{'rotate_check_file'}\n";
#        }
	}else{
		my $rotate_check_file_exists=-1;
		print "could not open $cnf->{'rotate_check_file'} \n" ;
	}

		open LOG_FILE, $cnf->{'file_name'} || die "Unable to open log file $cnf->{'file_name'}: $!"; #$cnf->{'file_name'}ファイルを開いてLOG_FILE定数に置き換える
			print "opened:$cnf->{'file_name'}...\n";		
	
		my $i=1;
		our $rotated=0;
		my $line;
		while ($line=<LOG_FILE>) {
			if($i==1){
				$this_first_line=$line;
			}
			$i=$i+1;
		}
		
	if($rotate_check_file_exists!=-1){
		#開始行に改行が無い場合の処置（最後に改行を付加して比較）
		if($this_first_line eq ""){
			$this_first_line="\n"
		}
		print "今回先頭行：$this_first_line\n";
		
		#前回の先頭行と同じかどうか確認
		if($this_first_line ne $before_first_line){
	#print "異なる\n";
			#異なるならばlogrotationが行われたものとみなし、フラグを立てる
			$rotated=1;
		}
	}else{
		$rotated=1;
		print "rotateチェックファイルが無い為rotate前のlogも実行\n"
	}
		
		close(LOG_FILE);
		print "...closed:$cnf->{'file_name'}\n";
	
	
	#print "rotated:$rotated\n";
	print "##################################################\n";

#	if($rotate_check_file_exists!=-1){
		#カレントディレクトリから作成日付が最も最近のbkファイルを検索し、これに対してtpl更新チェックを行う。
		if($rotated==1){
			print "log_file rotated!...\n";
			print "before_rotated_file load...======================================================\n";
			#use Date::Calc qw(:all);
			my $dir='/var/log/rsync';
			my $max_year=1970;
			my $max_month=01;
			my $max_day=01;
			my $cyear;
			my $cmon;
			my $cmday;
	print "directory file list:\n*****************************************************\n";
			foreach my $file ( grep -f, glob( "$dir/*" ) ) {
				$file =~ /ec_sync.log-(\d{4})(\d{2})(\d{2}).gz/;
	print "$file\n";
				$cyear = $1;
				$cmon = $2;
				$cmday = $3;
	
	#print "max:$max_year.$max_month.$max_day\n";
	#print "now:$cyear.$cmon.$cmday\n";
				#if(Date_to_Days($max_year,$max_month,$max_day) <= Date_to_Days($cyear,$cmon,$cmday)){
			     if($max_year.$max_month.$max_day <= $cyear.$cmon.$cmday){
			         $max_year=$cyear;
			         $max_month=$cmon;
			         $max_day=$cmday;
	#		         print '大きい\n';
			    }else{
	#		    	 print '小さい';
			    }
			}
	print "*****************************************************\n";
		
			my $date=$max_year.$max_month.$max_day;		
			my $before_rotate_file_name='/var/log/rsync/ec_sync.log-'.$date;
			
			if($date ne "197011"){
				print "before rotate file name:$before_rotate_file_name\n";
				#圧縮されている旧ログファイルを解凍する（元の圧縮ファイルは残す）
				system("gzip -c -d $before_rotate_file_name.gz > $before_rotate_file_name");
				
				@log_files_each_week = ( 
				   {'file_name' => $before_rotate_file_name,    #required file name
				   'reg_exp' =>'\.tpl',#required reg_exp
					'time' =>'START EC SYNC',#required reg_exp
				   },
				);
				&tpl_search(@log_files_each_week);
			}else{
				print "rotate前のlogがありませんでした\n"
			}
			
	#exit(0);
			#読み込み履歴を削除する
			my $seek_file_template='/var/log/rsync/ec_sync.tpl_update_check.seek';
			unlink $seek_file_template;
			#解凍ファイルを削除する
			unlink $before_rotate_file_name;
			
			print "======================================================\n";
		}else{
			print "not rotated...\n";
		}
#	}else{
#		print "pass\n"
#	}

	
#exit(0);
	#1日1回のログファイルチェック
	&tpl_search(@log_files_normal);
	

#print $cnf->{'rotate_check_file'};
	unlink $cnf->{'rotate_check_file'};
	my $rotate_check_file=$cnf->{'rotate_check_file'};
	open(ROTATE_CHECK_FILE,"> /var/log/rsync/ec_sync.tpl_logrotate_check.tmp") || die 
	print ROTATE_CHECK_FILE;
	print ROTATE_CHECK_FILE $this_first_line;
	close(ROTATE_CHECK_FILE);
	print "this_first_line:$this_first_line > $rotate_check_file...\n";
	
}







sub tpl_search{
	print "search start!...\n";
	#our @log_files;
	my @log_files;
	@log_files =@_;
	
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks);
	my $seek_file_template;
	$seek_file_template='/var/log/rsync/ec_sync.tpl_update_check.seek';
	my $find_result = '';


	foreach my $cnf ( @log_files ) {  #log_filesの設定を $cnf に代入する
	    my @seek_pos;
	    my $fbasename = $2;
	    
	    my $seek_file = $seek_file_template;
#	    print "[seek_file:".$seek_file_template."]\n";
	    next unless ( -r $cnf->{'file_name'} );
	    # Open log file
#print "file_name:";
#print "$cnf->{'file_name'}\n";
	    open LOG_FILE, $cnf->{'file_name'} || die "Unable to open log file $cnf->{'file_name'}: $!"; #$cnf->{'file_name'}ファイルを開いてLOG_FILE定数に置き換える
	    	print "opened $cnf->{'file_name'}...\n";
	    # Try to open log seek file.  If open fails, we seek from beginning of
	    # file by default.
	    if (open(SEEK_FILE, $seek_file)) { #ファイル読み込んでSEEK_FILE変数に格納
	        chomp(@seek_pos = <SEEK_FILE>); #改行削除
	        close(SEEK_FILE);
	        
	        #  If file is empty, no need to seek...
	        if ($seek_pos[0] != 0) {
print '前回実行時ファイルサイズ:'.$seek_pos[0]."\n";
	            # Compare seek position to actual file size.  If file size is smaller
	            # then we just start from beginning i.e. file was rotated, etc.
	            ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(LOG_FILE);
	            if ($seek_pos[0] <= $size) { #ログファイルよりもseek（古いファイル）の方がサイズが小さい場合は
	                seek(LOG_FILE, $seek_pos[0], 0); #ログファイルの中で、先頭から、seek（古いファイル）のところにポインタを移動
	            }
	        }
	    }

	    # Loop through every line of log file and check for pattern matches.
	    # Count the number of pattern matches and remember the full line of 
	    # the most recent match.
	    my $lc = 0;
	    my $add_lines = '';
	    my $pattern_line = '';
	    
	    my $time='';
	    my $pattern_count = 0;
		  $cnf->{'lines'} = 1 if  ! defined( $cnf->{'lines'} );

		# ログファイルからreg_expに該当する文字列を検索する
		my $line;
	    while ($line=<LOG_FILE>) {
	    	#print $line;
	    	#print "logfile";
				chomp ;
				s/\x0d//m;
	#			if ($lc !=0 && $lc < $cnf->{'lines'} ){
	#				if ( $cnf->{'new_line_reg_exp'} ) {
	#					if ( $_ !~ $cnf->{'new_line_reg_exp'} ) {
	#						$add_lines = $lc==1?$_:$add_lines . $_ ;
	#            			$lc++; 
	#					} else {
	#						$lc = $cnf->{'lines'}; #開始行を格納
	#					}
	#				} else { 	
	#        			$add_lines = $lc==1?$_:$add_lines . $_ ;
	#					$lc++; 
	#				}
	#			}
				
				if ($line =~ /$cnf->{'time'}/) {
					$time=$line; #start時刻を控える
				}
				
	# 			if ($line =~ $cnf->{'neg_reg_exp'}) { #抽出したくないパターン
	#				if (($line =~/$cnf->{'reg_exp'}/) && !($line =~/$cnf->{'neg_reg_exp'}/)) { #抽出したいパターンで抽出したくないパターンでない時は一致した文字（$_）を格納？
	#					$pattern_count += 1;
	#					$pattern_line =$pattern_line.$line;
	#				}
	#			} elseif ($line =~ /$cnf->{'reg_exp'}/) { #/$cnf->{'reg_exp'}/の正規表現に一致するならば一致した文字（$_）を格納
				if ($line =~ /$cnf->{'reg_exp'}/) { #/$cnf->{'reg_exp'}/の正規表現に一致するならば一致した文字（$_）を格納
	 				$pattern_count += 1;
	 				#print "前".$find_result;
					$find_result .=$time.":".$line."\n";
					#print "後".$find_result;
					$lc=1;
				}
	    }


	    # Overwrite log seek file and print the byte position we have seeked to.
	    open(SEEK_FILE, "> $seek_file") || die "Unable to open seek count file $seek_file: $!"; #上書き出力用としてseek fileをopenし、
#	    	print "opened $seek_file\n";
	    print SEEK_FILE tell(LOG_FILE); #ログファイルの現在位置を書きこむ
	    close(SEEK_FILE);
	    print "$cnf->{'file_name'}:file_size(";
	    print tell(LOG_FILE);
	    print ") > $seek_file...\n";
	    
#	    print "...closed $seek_file\n";
	    close(LOG_FILE);
#	    print "...closed $cnf->{'file_name'}\n";
	}

	#余分な文字を取り除く
	$find_result=~ s/(?:\*\*\* START EC SYNC \*\*\*)//g;

	if($find_result eq''){
			print "更新されたtplファイルはありません\n";
	}else{
		#メール送信
		print "更新されたtplファイルは以下です。\n";
		print $find_result;
		&mail($find_result);
	}
}

sub mail{
	#my $num1 = shift;
	#print $num1;

	my $sec;
	my $min;
	my $hour;
	my $mday;
	my $mon;
	my $year;
	my $wday;
	my $yday;
	my $isdst;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;

	use Encode;
	require '/root/work/j.pm';
	my $sendmail = '/usr/sbin/sendmail'; # sendmailコマンドパス
	my $from = 'dev-ipsa@teamfactory.jp'; # 送信元メールアドレス
	my $to = 'dev-ipsa@teamfactory.jp'; # あて先メールアドレス
	my $subject = "【IPSA】tplファイル更新チェックレポート（".$year."-".$mon."-".$mday."）"; # メールの件名
	#print $_[0];
	my $msg = "本番環境で以下のtplファイルが更新されました。\n本番と社内環境のソースを比較し、必要な場合はデザイン反映を行ってください。\n".$_[0]."\n\n[...]\nProject: IN-IPSA-OPE"; # メールの本文(ヒアドキュメントで変数に代入)
	
	# sendmail コマンド起動
	open(SDML,"| $sendmail -t -i") || die 'sendmail error';
	
	&Jcode::convert(\$subject,"ISO-2022-JP", "utf8");
	&Jcode::convert(\$msg,"ISO-2022-JP", "utf8");
	
	# メールヘッダ出力
	print SDML "From: $from\n";
	print SDML "To: $to\n";
	print SDML "Subject: $subject\n";
	print SDML "Content-Transfer-Encoding: 7bit\n";
#	print SDML "Content-Type: text/plain;\n\n";
	print SDML "Content-Type: text/plain; charset=\"ISO-2022-JP\"\n\n";
	# メール本文出力
	print SDML "$msg";
	# sendmail コマンド閉じる
	close(SDML); 
}
