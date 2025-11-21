SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GenUPSTrackNo                                  */
/* Creation Date: 10-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Generate UPS Tracking No  (SOS#171456)                      */
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
/* 22-Jul-2010  NJOW     1.1  182440 - Generate UPSP Confirmation No.   */
/* 19-Mar-2012  Ung      1.2  Add RDT compatible message                */
/************************************************************************/

CREATE PROC    [dbo].[isp_GenUPSTrackNo]
               @c_UPSAccNo      NVARCHAR(15)
,              @c_servicelevel  NVARCHAR(2) 
,              @c_ServiceType   NVARCHAR(2)
,              @c_CustDUNSNo    NVARCHAR(9)
,              @c_Storerkey     NVARCHAR(15)
,              @c_UPSTrackNo    NVARCHAR(20)  OUTPUT
,              @c_USPSConfirmNo NVARCHAR(22)  OUTPUT
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
           @n_starttcnt int
   
   DECLARE @c_runningno NVARCHAR(7),
           @c_prefix NVARCHAR(2),
           @c_tmptrackno_conv NVARCHAR(20),
           @n_pos int,
           @n_oddcnt int,
           @n_evencnt int,
           @n_checkdigit int,
           @n_len int,
           @n_sumoddeven int,
           @c_runningno2 NVARCHAR(8),
           @c_tmpuspsno NVARCHAR(22),
           @n_tmpuspsno numeric(38,0)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''
   SELECT @c_prefix = '1Z'

	 EXEC isp_getucckey 
				@c_UPSAccNo
        ,7
        ,@c_runningno  OUTPUT
        ,@b_Success    OUTPUT
        ,@n_err        OUTPUT
        ,@c_errmsg     OUTPUT
        ,@n_joinstorer = 0                    
   
   IF @b_Success <> 1 
   BEGIN
   	  SELECT @n_continue = 3
      SELECT @n_err = 75851
      SELECT @c_errmsg = 'isp_GenUPSTrackNo: ' + RTRIM(ISNULL(@c_errmsg,''))
   END
         
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  SELECT @c_tmptrackno_conv = RTRIM(@c_UPSAccNo) + RTRIM(@c_servicelevel) + @c_runningno
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'A', '2')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'B', '3')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'C', '4')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'D', '5')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'E', '6')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'F', '7')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'G', '8')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'H', '9')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'I', '0')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'J', '1')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'K', '2')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'L', '3')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'M', '4')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'N', '5')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'O', '6')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'P', '7')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'Q', '8')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'R', '9')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'S', '0')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'T', '1')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'U', '2')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'V', '3')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'W', '4')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'X', '5')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'Y', '6')
   	  SELECT @c_tmptrackno_conv = REPLACE(@c_tmptrackno_conv, 'Z', '7')
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN   	  
   	  SELECT @n_len = LEN(@c_tmptrackno_conv)
   	  SELECT @n_oddcnt = 0, @n_evencnt = 0
   	  
   	  SELECT @n_pos = 1
   	  WHILE @n_pos <= @n_len
   	  BEGIN
   	  	SELECT @n_oddcnt = @n_oddcnt + CAST(SUBSTRING(@c_tmptrackno_conv,@n_pos,1) AS int)
   	  	SELECT @n_pos = @n_pos + 2
   	  END
   	  
   	  SELECT @n_pos = 2
   	  WHILE @n_pos <= @n_len
   	  BEGIN
   	  	SELECT @n_evencnt = @n_evencnt + CAST(SUBSTRING(@c_tmptrackno_conv,@n_pos,1) AS int)
   	  	SELECT @n_pos = @n_pos + 2
   	  END
   	  
   	  SELECT @n_sumoddeven = @n_oddcnt + (@n_evencnt * 2)
      SELECT @n_checkdigit = 10 - (@n_sumoddeven % 10)
      IF @n_checkdigit = 10 
         SELECT @n_checkdigit = 0      
      SELECT @c_UPSTrackNo = @c_prefix + RTRIM(@c_UPSAccNo) + RTRIM(@c_servicelevel) + @c_runningno + CONVERT(char(1),@n_checkdigit)
   END
   
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_ServiceType <> '' AND @c_CustDUNSNo <> ''
   BEGIN
	    EXEC isp_getucckey 
		   		@c_Storerkey
           ,8
           ,@c_runningno2 OUTPUT
           ,@b_Success    OUTPUT
           ,@n_err        OUTPUT
           ,@c_errmsg     OUTPUT
           ,@n_joinstorer = 0                    
      
      IF @b_Success <> 1 
      BEGIN
      	 SELECT @n_continue = 3
         SELECT @n_err = 75852
         SELECT @c_errmsg = 'isp_GenUPSTrackNo: ' + RTRIM(ISNULL(@c_errmsg,''))
      END
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_ServiceType <> '' AND @c_CustDUNSNo <> ''
   BEGIN
   	   SET @c_tmpuspsno = '91' + RTRIM(@c_ServiceType) + RTRIM(@c_CustDUNSNo) + @c_runningno2
   	   SET @n_tmpuspsno = CAST(@c_tmpuspsno AS NUMERIC(38,0))   	   

   	   EXEC isp_CheckDigits 
          @n_tmpuspsno,
	       @n_checkdigit OUTPUT
	       
	     SET @c_USPSConfirmNo = RTRIM(@c_tmpuspsno) + CONVERT(char(1),@n_checkdigit)
   END 
	                   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1 -- (ChewKP05)
      BEGIN
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
          -- Instead we commit and raise an error back to parent, let the parent decide

          -- Commit until the level we begin with
          WHILE @@TRANCOUNT > @n_starttcnt
             COMMIT TRAN

          -- Raise error with severity = 10, instead of the default severity 16.
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
          RAISERROR (@n_err, 10, 1) WITH SETERROR

          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         SELECT @b_success = 0   
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GenUPSTrackNo'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO