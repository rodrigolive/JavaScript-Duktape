use lib './lib';
use strict;
use warnings;
use JavaScript::Duktape;
use Data::Dumper;
use Test::More;

my $js = JavaScript::Duktape->new();
my $duk = $js->duk;

my $count = 0;

$duk->push_function(sub {
	eval {};
	$count++;
	$duk->push_string("hi");
	die;
	$duk->require_string(99);
	fail("should never get here");
});

$duk->put_global_string("perlFn");


{  #eval with try
	eval {
		$duk->eval_string(qq~
			try {
				perlFn();
			} catch (e){
				throw(e);
			};
		~);
	};
	ok ($@, $@);
	is($count, 1, "called once");
}

{ #eval without try
	$count = 0;
	eval {
		$duk->eval_string(qq~
			perlFn();
		~);
	};
	ok ($@, $@);
	is($count, 1, "called once");

	my $top = $duk->get_top();
	is($top, 0, "Error on Top");
}

{  #peval with try/catch
	#reset
	$count = 0;
	eval {
		$duk->peval_string(qq~
			var ret;
			try {
				perlFn();
				perlFn();
			} catch (e){
				throw(e);
			};
		~);
	};


	ok (!$@, $@);
	is($count, 1, "called once");

	my $top = $duk->get_top();
	is($top, 1, "Error is on top");
	$duk->pop();
}


{  #peval without try/catch
	#reset
	$count = 0;
	eval {
		$duk->peval_string(qq~
			perlFn();
			perlFn();
		~);
	};

	ok (!$@, $@);
	is($count, 1, "called once");

	my $top = $duk->get_top();
	is($top, 1, "Error is on top");
	my $err_str = $duk->to_string(0);
	ok($err_str =~ /^Error: Died at/, $err_str);
}


{
	#overwrite perl function
	$js->set('perlFn', sub {
		eval {};
		$count++;
		$duk->push_string("hi");
		$duk->require_string(99);
		fail("should never get here");
	});

	$duk->peval_string("perlFn");
	eval {
		$duk->call(0);
	};

	ok ($@ =~ /^duktape uncaught error/, $@);

	$duk->eval_string("perlFn");
	eval {
		$duk->pcall(0);
	};
	ok (!$@);

	my $str = $duk->to_string(0);
	is($str, "TypeError: not string");
}

done_testing(15);
