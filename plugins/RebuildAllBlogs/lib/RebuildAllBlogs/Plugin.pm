package RebuildAllBlogs::Plugin;

use strict;

sub _rebuild_confirm {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $plugin = $app->component( 'RebuildAllBlogs' );
    my $pointer_field = $tmpl->getElementById( 'dbtype' );
    my $nodeset = $tmpl->createElement( 'app:setting', { id => 'rebuild_all', label => $plugin->translate( 'Rebuild All' ) , show_label => 0 } );
    my $innerHTML = <<MTML;
<__trans_section component="RebuildAllBlogs">
<p style="margin-top:1em">
    <label id="rebuild_all-wrapper"><input onchange="select_all( this );" type="checkbox" id="rebuild_all" name="rebuild_all" value="<mt:var name="rebuild_all">" <mt:if name="rebuild_next">checked="checked"</mt:if> /> <__trans phrase="Rebuild All"></label>
</p>
<mt:unless name="rebuild_next">
    <input type="hidden" name="start_rebuild" value="1" />
</mt:unless>
<script type="text/javascript">
function select_all( cb ) {
    if ( cb.checked ) {
        getByID( 'type' ).selectedIndex = 0;
    }
}
<mt:if name="rebuild_all">getByID( 'type' ).selectedIndex = 0;
</mt:if>
</script>
<mt:if name="rebuild_next"><script type="text/javascript">
    getByID( 'rebuild' ).submit();
</script>
</mt:if>
</__trans_section>
MTML
    my $inner = $pointer_field->innerHTML;
    $inner =~ s/<select/<select id="type"/;
    $pointer_field->innerHTML( $inner . $innerHTML );
    my $rebuild_all = $app->param( 'rebuild_all' );
    $param->{ rebuild_next } = $rebuild_all;
    $rebuild_all = $app->make_magic_token unless $rebuild_all;
    $param->{ rebuild_all } = $rebuild_all;
}

sub _confirm_header {
    my ( $cb, $app, $tmpl ) = @_;
    if ( $app->mode ne 'rebuild_confirm' ) {
        return 1;
    }
    if ( $app->param( 'rebuild_all' ) ) {
        my $css = '<style type="text/css">body{display:none}</style>';
        $$tmpl =~ s!(</head>)!$css$1!;
    }
}

sub _confirm_source {
    my ( $cb, $app, $tmpl ) = @_;
    my $pointer = quotemeta( '<form method="post" ' );
    my $new = 'id="rebuild" ';
    $$tmpl =~ s/($pointer)/$1$new/;
}

sub _rebuilding_source {
    my ( $cb, $app, $tmpl ) = @_;
    my $new = '<mt:if name="rebuild_blogs">&rebuild_blogs=<$mt:var name="rebuild_blogs" escape="url"$></mt:if><mt:if name="rebuild_all">&rebuild_all=<$mt:var name="rebuild_all" escape="url"$></mt:if>';
    $$tmpl =~ s/(__mode=rebuild)/$1$new/;
}

sub _rebuilding {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my @blog_ids;
    my $rebuild_all = $app->param( 'rebuild_all' );
    if ( ( $rebuild_all ) && ( $app->mode eq 'start_rebuild' ) ) {
        my $email = $app->user->email;
        require MT::Session;
        my $sess = MT::Session->get_by_key( { id => $rebuild_all, email => $email, kind => 'RB' } );
        if ( $app->param( 'start_rebuild' ) ) {
            @blog_ids = __rebuild_blogs( $app );
        } else {
            my $data = $sess->data;
            @blog_ids = split( /,/, $data ) if $data;
        }
        my @new_ids;
        for my $id ( @blog_ids ) {
            if ( $id != $app->param( 'blog_id' ) ) {
                push @new_ids, $id;
            }
        }
        $sess->data( join ( ',', @new_ids ) );
        if (! $sess->start ) {
            $sess->start( time );
        }
        $sess->save or die $sess->errstr;
    }
    $param->{ rebuild_all } = $app->param( 'rebuild_all' );
}

sub __rebuild_blogs {
    my $app = shift;
    my $author_id = $app->user->id;
    require MT::Permission;
    my %params1 = ( author_id   => $author_id,
                    blog_id     => { not => 0 },
                    permissions => { like => "%'rebuild'%" } );
    my %params2 = ( author_id   => $author_id,
                    blog_id     => { not => 0 },
                    permissions => { like => "%'administer'%" } );
    my @perms = MT::Permission->load( [ \%params1, '-or', \%params2, ] );
    my @blog_ids;
    for my $perms ( @perms ) {
        push ( @blog_ids, $perms->blog_id );
    }
    return @blog_ids;
}

sub _rebuilt {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $pointer_field = $tmpl->getElementById( 'message' );
    my $insertHTML = <<MTML;
    <__trans_section component="RebuildAllBlogs">
    <mt:if name="rebuild_time">
    (<__trans phrase="Total publish time: [_1]." params="<mt:var name="rebuild_time">">)
    </mt:if>
    </__trans_section><mt:if name="start_timestamp">
MTML
    my $block = $pointer_field->innerHTML;
    my $pointer = quotemeta( '<mt:if name="start_timestamp">' );
    $block =~ s/$pointer/$insertHTML/;
    $pointer_field->innerHTML( $block );
    my $rebuild_all = $app->param( 'rebuild_all' );
    my $next;
    if ( $rebuild_all ) {
        $param->{ rebuild_all } = $rebuild_all;
        my $email = $app->user->email;
        require MT::Session;
        my $sess = MT::Session->load( { id => $rebuild_all, email => $email, kind => 'RB' } );
        my $rebuild_blogs;
        if ( $sess && $sess->data ) {
            $rebuild_blogs = $sess->data;
            my $blog_id = $app->param( 'blog_id' );
            my @blogs = split( /,/, $rebuild_blogs );
            my @new_ids;
            for my $id ( @blogs ) {
                if ( ( $id ) && ( $id != $blog_id ) ) {
                    push ( @new_ids, $id );
                }
            }
            if ( scalar @new_ids ) {
                $rebuild_blogs = join ( ',', @new_ids );
                $next = $new_ids[ 0 ];
                $param->{ next } = $next;
            }
        } else {
            if ( $sess ) {
                my $rebuild_time = time - $sess->start;
                $param->{ rebuild_time } = $rebuild_time;
                $sess->remove or die $sess->errstr;
            }
        }
    }
    if ( $rebuild_all && $next ) {
        my $url = $app->base . $app->uri( mode => 'rebuild_confirm',
                                args => { blog_id => $next,
                                          rebuild_all => $rebuild_all, } );
        return $app->redirect( $url );
    }
}

1;