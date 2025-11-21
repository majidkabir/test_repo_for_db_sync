SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GenUPSShipmentNo                               */
/* Creation Date: 10-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Generate UPS Shipment No  (SOS#171456)                      */
/*                                                                      */
/* Called By: Precartonize Packing                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[isp_GenUPSShipmentNo]
               @c_UPSTrackNo    NVARCHAR(20)
,              @c_UPSShipmentNo NVARCHAR(18)  OUTPUT
,              @b_Success       int       OUTPUT
,              @n_err           int       OUTPUT
,              @c_errmsg        NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,  
           @n_cnt int
   
   DECLARE @n_tmptrackno int,
           @c_upsaccno NVARCHAR(6),
           @c_convchar NVARCHAR(1),
           @n_pos1 int,
           @n_pos2 int,
           @n_pos3 int,
           @n_pos4 int,
           @n_pos5 int,
           @c_pos1 NVARCHAR(1),
           @c_pos2 NVARCHAR(1),
           @c_pos3 NVARCHAR(1),
           @c_pos4 NVARCHAR(1),
           @c_pos5 NVARCHAR(1)

   SELECT @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''
         
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  SELECT @c_upsaccno = SUBSTRING(@c_UPSTrackNo,3,6)
   	  SELECT @n_tmptrackno = CAST(SUBSTRING(@c_UPSTrackNo,11,7) AS int)
   	  SELECT @n_pos1 = @n_tmptrackno / power(26 , 4)
      SELECT @n_pos2 = (@n_tmptrackno-(@n_pos1*power(26,4)))/power(26,3)
      SELECT @n_pos3 = (@n_tmptrackno-(@n_pos1*power(26,4))-(@n_pos2*power(26,3)))/power(26,2)
      SELECT @n_pos4 = (@n_tmptrackno-(@n_pos1*power(26,4))-(@n_pos2*power(26,3))- (@n_pos3*power(26,2)))/26
      SELECT @n_pos5 = (@n_tmptrackno-(@n_pos1*power(26,4))-(@n_pos2*power(26,3))-(@n_pos3*power(26,2))- (@n_pos4*26))
      
      SELECT @n_cnt = 0, @c_pos1 = '', @c_pos2 = '', @c_pos3 = '', @c_pos4 = '', @c_pos5 = ''
      WHILE @n_cnt <= 25
      BEGIN
      	 IF @n_cnt >= 0 AND @n_cnt <= 1
      	    SELECT @c_convchar = master.dbo.fnc_GetCharASCII(51 + @n_cnt) --3,4
      	 IF @n_cnt >= 2 AND @n_cnt <= 4
      	    SELECT @c_convchar = master.dbo.fnc_GetCharASCII(55-2 + @n_cnt) --7,8,9
      	 IF @n_cnt >= 5 AND @n_cnt <= 7
      	    SELECT @c_convchar = master.dbo.fnc_GetCharASCII(66-5 + @n_cnt) --B,C,D
      	 IF @n_cnt >= 8 AND @n_cnt <= 10
      	    SELECT @c_convchar = master.dbo.fnc_GetCharASCII(70-8 + @n_cnt) --F,G,H
      	 IF @n_cnt >= 11 AND @n_cnt <= 15
      	    SELECT @c_convchar = master.dbo.fnc_GetCharASCII(74-11 + @n_cnt) --J to N      	    
      	 IF @n_cnt >= 16 AND @n_cnt <= 20
      	    SELECT @c_convchar = master.dbo.fnc_GetCharASCII(80-16 + @n_cnt) --P to T      	    
      	 IF @n_cnt >= 21 AND @n_cnt <= 25
      	    SELECT @c_convchar = master.dbo.fnc_GetCharASCII(86-21 + @n_cnt) --V to Z

      	 IF @n_cnt = @n_pos1
      	    SELECT @c_pos1 = @c_convchar
      	 IF @n_cnt = @n_pos2
      	    SELECT @c_pos2 = @c_convchar
      	 IF @n_cnt = @n_pos3
      	    SELECT @c_pos3 = @c_convchar
      	 IF @n_cnt = @n_pos4
      	    SELECT @c_pos4 = @c_convchar
      	 IF @n_cnt = @n_pos5
      	    SELECT @c_pos5 = @c_convchar
      	 
      	 SELECT @n_cnt = @n_cnt + 1
      END
      
      SELECT @c_UPSShipmentNo = @c_upsaccno + @c_pos1 + @c_pos2 + @c_pos3 + @c_pos4 + @c_pos5
   	     	 
   END
                     
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0   
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GenUPSShipmentNo'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      RETURN
   END
END   

GO