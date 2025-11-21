SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_getucckey                                       */
/* Creation Date: 03-Nov-2008                                            */
/* Copyright: IDS                                                        */
/* Written by: YTWAN                                                     */
/*                                                                       */
/* Purpose:  SOS#119744 - Geneate UCC Label for IDSUS.                   */
/*                                                                       */
/* Input Parameters:  @c_storerkey,                                      */
/*                    @c_fieldlength,                                    */
/*                    @b_resultset,                                      */
/*                    @n_batch,                                          */
/*                    @n_joinstorer                                      */
/*                                                                       */
/* Output Parameters: @c_keystring                                       */
/*                    @b_Success                                         */
/*                    @n_err      												               */          
/*                    @c_errmsg   												               */          
/*                                  												             */           
/* Return Status: b_Success  1 OR 0                                      */
/*                                                                       */
/* Usage:                                                                */
/*                                                                       */
/* Local Variables:                                                      */
/*                                                                       */
/* Called By:  Precartonize Packing screen - ue_new_carton()             */
/*                                                                       */
/* PVCS Version: 1.0       -- Change this PVCS next version release      */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver.  Purposes                                 */
/* 10-May-2010  NJOW01    1.1   SOS#171456 - Add a parameter to determine*/
/*                              whether join storer table.               */
/*************************************************************************/

CREATE PROC    [dbo].[isp_getucckey] 
					@c_storerkey   NVARCHAR(15)
,              @c_fieldlength int
,              @c_keystring   NVARCHAR(25)       OUTPUT
,              @b_Success     int            OUTPUT
,              @n_err         int            OUTPUT
,              @c_errmsg      NVARCHAR(250)      OUTPUT
,              @b_resultset   int       = 0
,              @n_batch       int       = 1
,              @n_joinstorer  int       = 1 --NJOW01
AS
   SET NOCOUNT ON		
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF   

	DECLARE @n_count int /* next key */
	DECLARE @n_ncnt int
	DECLARE @n_starttcnt int /* Holds the current transaction count */
	DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 
                              4=successful but skip furthur processing */
	DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */
	DECLARE @d_startusedate datetime
	DECLARE @n_rowcnt int
	DECLARE @n_startucc int
   DECLARE @n_KeyCount int
	DECLARE @n_EndUCC   int

	SET @n_starttcnt=@@TRANCOUNT
	SET @n_continue=1
	SET @b_success=0
	SET @n_err=0
	SET @c_errmsg=''
   
	
	BEGIN TRANSACTION 
	
	IF @n_joinstorer = 1 --NJOW01
	BEGIN
	  SELECT @n_rowcnt = 1,
	         @d_startusedate = U.StartUseDate,
           @n_StartUCC = ISNULL(U.StartUCC,0),
           @n_KeyCount = ISNULL(U.KeyCount,0), 
		    	 @n_EndUCC   = ISNULL(U.EndUCC,0)
	  FROM UCCCounter U WITH (NOLOCK) 
    INNER JOIN STORER S WITH (NOLOCK)
          ON (U.Storerkey = S.LabelPrice)
	  WHERE  S.Storerkey = @c_storerkey
	  --AND  StartUCC + KeyCount > EndUCC
	END
	ELSE
	BEGIN
	  SELECT @n_rowcnt = 1,
	         @d_startusedate = U.StartUseDate,
           @n_StartUCC = ISNULL(U.StartUCC,0),
           @n_KeyCount = ISNULL(U.KeyCount,0), 
		    	  @n_EndUCC   = ISNULL(U.EndUCC,0)
	  FROM UCCCounter U WITH (NOLOCK) 
	  WHERE  U.Storerkey = @c_storerkey
  END
	
	IF @n_rowcnt > 0
	BEGIN 
		IF @n_StartUCC + @n_KeyCount > @n_EndUCC
		BEGIN
		   IF DateAdd(Year, 1, @d_startusedate) - 1 > GetDate()
			BEGIN 
				SET @n_continue = 3
			   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61901   
			   SELECT @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Checking Failed On UCCcounter:'+ISNULL(RTRIM(LTRIM(@c_storerkey)),'')+
	                          '. (isp_getucckey)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(LTRIM(@c_errmsg)),'') + ' ) '
			
			END
			ELSE
			BEGIN
        IF @n_joinstorer = 1 --NJOW01
        BEGIN
				  UPDATE UCCCounter WITH (ROWLOCK)
	               SET keycount = 0,  
					       StartUseDate = GetDate() 
				  FROM Storer S WITH (NOLOCK)
          WHERE UCCCounter.Storerkey = S.LabelPrice
	        AND S.Storerkey = @c_storerkey	        
	      END
	      ELSE
	      BEGIN
				  UPDATE UCCCounter WITH (ROWLOCK)
	               SET keycount = 0,  
					       StartUseDate = GetDate() 
          WHERE UCCCounter.Storerkey = @c_storerkey
	      END

				SET @n_err = @@ERROR
            SET @n_cnt = @@ROWCOUNT
				
				IF @n_err <> 0
				BEGIN
					SET @n_continue = 3 
				   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		         SELECT @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Update Failed On UCCounter:'+ISNULL(RTRIM(LTRIM(@c_storerkey)),'')+
	                             '. (isp_getucckey)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(LTRIM(@c_errmsg)),'') + ' ) '
				END
			END 
		END
	END
	ELSE
	BEGIN
		SET @n_continue = 3
		SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61903   
		SELECT @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Storer: '+ISNULL(RTRIM(LTRIM(@c_storerkey)),'')+
                       ' not setup in UCCcounter Or Storer. (isp_getucckey)' + 
                       ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(LTRIM(@c_errmsg)),'') + ' ) '
	END 
	
	
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
    IF @n_joinstorer = 1 --NJOW01		
    BEGIN
     	 UPDATE UCCCounter WITH (ROWLOCK)
            	SET keycount = keycount 
       FROM Storer S WITH (NOLOCK)
       WHERE UCCCounter.Storerkey = S.LabelPrice
       AND S.Storerkey = @c_storerkey
    END
    ELSE
    BEGIN
     	 UPDATE UCCCounter WITH (ROWLOCK)
            	SET keycount = keycount 
       WHERE UCCCounter.Storerkey = @c_storerkey
    END
       
		SET @n_err = @@ERROR 
		SET @n_cnt = @@ROWCOUNT
		
		IF @n_err <> 0
		BEGIN
		  SET @n_continue = 3 
		END
	END 
	
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
	  IF @n_cnt > 0
	  BEGIN
	
        IF @n_joinstorer = 1 --NJOW01		
        BEGIN
	         UPDATE UCCCounter WITH (ROWLOCK)
                  SET keycount = keycount + @n_batch, 
	                StartUseDate = CASE WHEN StartUseDate IS NULL THEN Getdate() ELSE StartUseDate end 
			     FROM Storer S WITH (NOLOCK)
           WHERE UCCCounter.Storerkey = S.LabelPrice
           AND S.Storerkey = @c_storerkey
        END
        ELSE
        BEGIN
	         UPDATE UCCCounter WITH (ROWLOCK)
                  SET keycount = keycount + @n_batch, 
	                StartUseDate = CASE WHEN StartUseDate IS NULL THEN Getdate() ELSE StartUseDate end 
           WHERE UCCCounter.Storerkey = @c_storerkey
        END
           

			SET @n_err = @@ERROR 
         SET @n_cnt = @@ROWCOUNT
	
	      IF @n_err <> 0
	      BEGIN
	          SET @n_continue = 3 
	          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	          SELECT @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Update Failed On UCCounter:'+ISNULL(RTRIM(LTRIM(@c_storerkey)),'')+
                              '. (isp_getucckey)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(LTRIM(@c_errmsg)),'') + ' ) '
	      END
	      ELSE IF @n_cnt = 0
	      BEGIN
	          SET @n_continue = 3 
	          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61905
	          SELECT @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Update To Table UCCounter:'+ISNULL(RTRIM(LTRIM(@c_storerkey)),'')+
                              ' Returned Zero Rows Affected. (isp_getucckey)'
	      END
	  END
	  ELSE BEGIN
	      --INSERT UCCcounter (Storerkey , keycount, StartUseDate) VALUES (@c_storerkey, @n_batch, GetDate())
	
	      SET @n_err = @@ERROR
	
	      IF @n_err <> 0
	      BEGIN
	          SET @n_continue = 3 
	          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61906   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	          SELECT @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Insert Failed On UCCcounter:'+ISNULL(RTRIM(LTRIM(@c_storerkey)),'')+
                              '. (isp_getucckey)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(LTRIM(@c_errmsg)),'') + ' ) '
	      END
	  END
	
	  IF @n_continue=1 OR @n_continue=2
	  BEGIN
        IF @n_joinstorer = 1 --NJOW01			 
        BEGIN 	
	         SELECT @n_count = (U.STARTUCC + U.keycount) - @n_batch 
           FROM UCCcounter U  WITH (NOLOCK)
           INNER JOIN STORER S WITH (NOLOCK)
           ON (U.Storerkey = S.Labelprice)
           WHERE S.Storerkey = @c_storerkey
         END
         ELSE
         BEGIN
	         SELECT @n_count = (U.STARTUCC + U.keycount) - @n_batch 
           FROM UCCcounter U  WITH (NOLOCK)
           WHERE U.Storerkey = @c_storerkey
         END
	
	      SET @c_keystring = RTRIM(LTRIM(CONVERT(CHAR(18),@n_count )))
	
	      DECLARE @bigstring NVARCHAR(50)

	      SET @bigstring = ISNULL(RTRIM(@c_keystring),'')
	      SET @bigstring = Replicate('0',25) + @bigstring
	      SET @bigstring = ISNULL(RIGHT(RTRIM(@bigstring), @c_fieldlength),'')
	      SET @c_keystring = ISNULL(RTRIM(@bigstring),'')
	
	      IF @b_resultset = 1
	      BEGIN
	          SELECT @c_keystring 'c_c_keystring', @b_Success 'b_success', @n_err 'n_err', @c_errmsg 'c_errmsg' 
	      END
	  END
	END

	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
	  SELECT @b_success = 0     
	  IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
	      BEGIN
	          ROLLBACK TRAN
	      END
	      ELSE BEGIN
	          WHILE @@TRANCOUNT > @n_starttcnt 
	          BEGIN
	              COMMIT TRAN
	          END          
	      END
	     EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_getucckey'
	     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	     RETURN
	  END
	  ELSE BEGIN
			SELECT @b_success = 1
			WHILE @@TRANCOUNT > @n_starttcnt 
			BEGIN
	          COMMIT TRAN
			END
			RETURN
	END

GO