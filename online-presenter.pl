use Mojolicious::Lite;
use Mojo::EventEmitter;

my %presentations;
my $events = Mojo::EventEmitter->new();

# present or view
get '/:operation/:name' => [operation => ['present', 'view']] => sub {
    my $c = shift;
    
    # find all svg files for this presentation
    opendir my $dh, 'public/presentations/' . $c->param('name') or die $!;
    my @svg;
    while (my $f = readdir $dh) {
        if ($f =~ /\.svg$/i) {
            push @svg, $f;
        }
    }
    @svg or die 'No svg files';
    
    @svg = sort { (split /\./, $a, 2)[0] <=> (split /\./, $b, 2)[0] } @svg;
    
    # other logic is inside template
    $c->render($c->param('operation'), svg => \@svg);
};

# control websocket for presenter
websocket '/ws/present/:name' => sub {
    my $c = shift;
    $c->inactivity_timeout(300);
    
    my $p = $c->param('name');
    
    # immediately send number of viewers
    $c->send( $presentations{$p}{viewers}||0 );
    # and then if somebody connected/disconnected
    my $cb = $events->on(viewers => sub {
        my ($e, $name) = @_;
        
        # is this our presentation
        return if $name ne $p;
        
        $c->send( $presentations{$p}{viewers} );
    });
    
    # slide was changed
    $c->on(message => sub {
        my ($c, $msg) = @_;
        
        $presentations{$p}{slide} = $msg;
        # notify all viewers
        $events->emit(slide => $p);
    });
    
    $c->on(finish => sub {
        $events->unsubscribe(viewers => $cb);
    });
};

# control websocket for presentation viewers
websocket '/ws/view/:name' => sub {
    my $c = shift;
    $c->inactivity_timeout(300);
    
    my $p = $c->param('name');
    
    # immediately send slide number
    $c->send( $presentations{$p}{slide}||0 );
    # and then if slide was changed
    my $cb = $events->on(slide => sub {
        my ($e, $name) = @_;
        
        # is this our presentation
        return if $name ne $p;
        
        $c->send( $presentations{$p}{slide} );
    });
    
    # change viewers number
    $presentations{$p}{viewers}++;
    $events->emit(viewers => $p);
    $c->on(finish => sub {
        $presentations{$p}{viewers}--;
        $events->emit(viewers => $p);
        $events->unsubscribe(slide => $cb);
    });
};

app->start;

__DATA__
@@present.html.ep
<html>
    <head>
        <title></title>
        <script src="//code.jquery.com/jquery-3.3.1.min.js"></script>
        <script>
            $(function() {
                var socket;
                function mkSocket() {
                    socket = new WebSocket("ws://"+window.location.host+"/ws/present/<%= param('name') %>");
                    socket.onopen = function() {
                        socket.send($('#preview > img[border="1"]').prop('name'));
                    }
                    socket.onclose = socket.onerror = mkSocket;
                    socket.onmessage = function(event) {
                        document.title = event.data + " viewers";
                    }
                }
                
                mkSocket();
                
                $('#preview > img').click(function() {
                    $('#preview > img[border="1"]').prop('border', 0);
                    socket.send(this.name);
                    $('#slide').prop('src', this.src);
                    this.border = 1;
                    this.scrollIntoView();
                })
                
                $('#left-arrow').click(function() {
                    $('#preview > img[border="1"]').prev().click();
                })
                
                $('#right-arrow').click(function() {
                    $('#preview > img[border="1"]').next().click();
                })
            })
        </script>
    </head>
    <body style="margin:0">
        <span style="font-size: 50pt; float: left; cursor: pointer;" id="left-arrow">⬅</span>
        <span style="font-size: 50pt; float: right; cursor: pointer;" id="right-arrow">➡</span>
        <div style="widht:100%; height: 150px; overflow: auto; overflow-y: hidden; white-space: nowrap;" id="preview">
            % my $i = 0;
            % for my $slide (@$svg) {
                <img src="/presentations/<%= param('name') %>/<%= $slide %>" style="height: 150px; cursor: pointer;" border="<%= $i == 0 ? 1 : 0 %>" name="<%= $i %>">
                % $i++;
            % }
        </div>
         <img src="/presentations/<%= param('name') %>/<%= $svg->[0] %>" style="height: calc(100% - 150px);" id="slide">
    </body>
</html>

@@view.html.ep
<html>
    <body style="margin:0">
        % my $i = 0;
        % for my $slide (@$svg) {
            <img src="/presentations/<%= param('name') %>/<%= $slide %>" id="<%= $i %>" style="height: 100%; display:none">
            % $i++;
        % }
        <script>
            var socket;
            var slide;
            function mkSocket() {
                socket = new WebSocket("ws://"+window.location.host+"/ws/view/<%= param('name') %>");
                socket.onclose = socket.onerror = mkSocket;
                socket.onmessage = function(event) {
                    if (slide) document.getElementById(slide).style.display = 'none';
                    slide = event.data;
                    document.getElementById(slide).style.display = 'block';
                }
            }
            
            mkSocket();
        </script>
    </body>
</html>
