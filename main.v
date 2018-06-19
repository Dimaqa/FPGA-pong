module main(
	output [3:0]VGA_R,
	output [3:0]VGA_G, 
	output [3:0]VGA_B,
	input CLOCK_50,
	input [3:0]KEY,
	output VGA_HS,
	output VGA_VS
);

reg [9:0] ballX;
reg [8:0] ballY;
reg [8:0] PaddlePosition;

initial ballX = 310;
initial ballY= 456;
initial PaddlePosition = 255;

reg    [31:0]VGA_CLK_o;
assign VGA_CLK        =VGA_CLK_o[0];
always @(posedge CLOCK_50) VGA_CLK_o=VGA_CLK_o+1;

wire inDisplayArea;
wire [11:0] CounterX;
wire [11:0] CounterY;
	hvsync_generator vga0(
		.pixel_clk(VGA_CLK),
		.h_fporch (16),
		.h_sync   (96), 
		.h_bporch (48),
		
		.v_fporch (10),
		.v_sync   (10),
		.v_bporch (33),
		.vga_hs   (VGA_HS),
		.vga_vs   (VGA_VS),
		.vga_blank(inDisplayArea),
		.CounterY(CounterY),
		.CounterX(CounterX) 
	);

//define borders
wire paddle = (CounterX>=PaddlePosition+8) && (CounterX<=PaddlePosition+120) && (CounterY[8:3]==59);
wire border = (CounterX[9:3]==0) || (CounterX[9:3]==79) || (CounterY[8:3]==0) ; 
wire BouncingObject = border | paddle;

localparam stpoint = 180;
wire p =  CounterX >= stpoint +   0 && CounterX <= stpoint +   5 &&  CounterY >= 100 && CounterY <= 130 || CounterX >= stpoint + 5 &&  CounterX <= stpoint + 25 && ( CounterY >= 100 && CounterY <=105 || CounterY >=115 && CounterY <=120) ||(CounterX>= stpoint + 20 && CounterX <= stpoint + 25 && CounterY>=100 && CounterY <=120 );
wire a = (CounterX >= stpoint +  60 && CounterX <= stpoint +  65 ||  CounterX >= stpoint + 80 && CounterX <= stpoint + 85) && CounterY >= 100 && CounterY <= 130 || CounterX >= stpoint +60 &&  CounterX<=stpoint +85 && ( CounterY >=100 && CounterY <=105 || CounterY >=115 && CounterY <=120);
wire u = (CounterX >= stpoint + 120 && CounterX <= stpoint + 125 ||  CounterX >= stpoint + 140 && CounterX <= stpoint + 145) && CounterY >= 100 && CounterY <= 130 || CounterX >= stpoint + 125 &&  CounterX<= stpoint +145 &&  CounterY >=125 && CounterY <=130;
wire s =  CounterX >= stpoint + 180 && CounterX <= stpoint + 205 && (CounterY >= 100 && CounterY <=105 || CounterY >= 115 && CounterY <=120 || CounterY >= 125 && CounterY <= 130) || CounterX >= stpoint + 180 &&  CounterX<= stpoint + 185 && CounterY >=105 && CounterY <=115 || CounterX >= stpoint + 200 &&  CounterX<= stpoint + 205 && CounterY >=115 && CounterY <=125;
wire e =  CounterX >= stpoint + 240 && CounterX <= stpoint + 265 && (CounterY >= 100 && CounterY <=105 || CounterY >= 115 && CounterY <=120 || CounterY >= 125 && CounterY <= 130) || CounterX >= stpoint + 240 && CounterX <= stpoint + 245 && CounterY >= 100 && CounterY <= 130;
wire pause = (p | a | u | s | e ) & !start;

//speed of ball and start/pause
reg [17:0]speed;
reg start = 0;
wire nextpos = (speed == 0);
reg over = 0;
always @(posedge CLOCK_50)
begin
	speed = speed + 1;
	if(over) start = 0; 
	else if(~KEY[3]) start = 1;
end
//
//move paddle
reg [6:0]boost = 6'b1; // move faster if hold button
reg [22:0]clock06s = 0;
always @(posedge CLOCK_50)
begin
	clock06s = clock06s + 1;
	if(clock06s == 0)
		if(boost != 5'd31)
			if(~KEY[0] & KEY[1] | KEY[0] & ~KEY[1] )
				boost = boost + 1;
			else
				boost = 1;			
end
always @(posedge nextpos)
begin
    if(over)
		PaddlePosition = 255;
	else
	if(start)
	begin
      if(~KEY[0]) 
      
		if(PaddlePosition  > (9'd511 - boost)) 
			PaddlePosition = 9'd511;
		else
			PaddlePosition = PaddlePosition + boost; 
	  if(~KEY[1]) 
		  if(PaddlePosition  < boost) 
			PaddlePosition = 0;
		  else
			PaddlePosition = PaddlePosition - boost;
	end			
end
//
//define ball
reg ball_inX, ball_inY;

always @(posedge VGA_CLK)
if(ball_inX==0) ball_inX <= (CounterX==ballX) & ball_inY; else ball_inX <= !(CounterX==ballX+16);

always @(posedge VGA_CLK)
if(ball_inY==0) ball_inY <= (CounterY==ballY); else ball_inY <= !(CounterY==ballY+16);

wire ball = ball_inX & ball_inY;
//

//define bounces
reg CollisionX1, CollisionX2, CollisionY1, CollisionY2;
always @(posedge VGA_CLK) if(nextpos | over) CollisionX1<=0; else if(BouncingObject & (CounterX==ballX   ) & (CounterY==ballY+ 8)) CollisionX1<=1;
always @(posedge VGA_CLK) if(nextpos | over) CollisionX2<=0; else if(BouncingObject & (CounterX==ballX+16) & (CounterY==ballY+ 8)) CollisionX2<=1;
always @(posedge VGA_CLK) if(nextpos | over) CollisionY1<=0; else if(BouncingObject & (CounterX==ballX+ 8) & (CounterY==ballY   )) CollisionY1<=1;
always @(posedge VGA_CLK) if(nextpos | over) CollisionY2<=0; else if(BouncingObject & (CounterX==ballX+ 8) & (CounterY==ballY+16)) CollisionY2<=1;
//

reg ball_dirX, ball_dirY;
always @(posedge nextpos)//UpdateBallPosition 
begin
	//reset if out of field
	if(ballY > 460)
	begin
		ballY = 456; ballX = 310; over = 1;
	end
	//else change coord
	else
	begin
		over = 0;
		if(start)
		begin
			if(~(CollisionX1 & CollisionX2))       
			begin
			if(CollisionY2) //&& ballX+boost < 9'b1001111000 && ballX-boost > 3'b111 )
				ballX <= ballX + (ball_dirX ? -boost : boost);
			else
				ballX <= ballX + (ball_dirX ? -1 : 1);
				if(CollisionX2) ball_dirX <= 1; else if(CollisionX1) ball_dirX <= 0;
			end

			if(~(CollisionY1 & CollisionY2))        
			begin
				ballY <= ballY + (ball_dirY ? -1 : 1);
				if(CollisionY2) ball_dirY <= 1; else if(CollisionY1) ball_dirY <= 0;
			end
		end
	end
end 

//define VGA outputs
wire R = BouncingObject | ball | pause;
wire G = BouncingObject;
wire B = BouncingObject;

assign  VGA_R = {4{R}} & {4{inDisplayArea}};
assign  VGA_G = {4{G}} & {4{inDisplayArea}};
assign  VGA_B = {4{B}} & {4{inDisplayArea}};
//
endmodule