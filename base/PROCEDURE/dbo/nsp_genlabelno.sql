SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Generate Label No                                           */
/*                                                                      */
/* Called from Packing script                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 12-08-2011 1.0  James      Add new config GenGenericUCCLabelNo to    */
/*                            segregate TBL model and generic (james01) */
/* 30-06-2015 1.1  NJOW01     340638-Fix incorrect carton# at PODUser   */
/* 24-06-2018 1.2  NJOW02     WMS-4808 HKGBG bebe configure custom sp to*/
/*                            generate label no                         */
/************************************************************************/
CREATE PROC [dbo].[nsp_GenLabelNo] (
	@c_orderkey	   NVARCHAR(10),
	@c_storerkey   NVARCHAR(15),
	@c_labelno	   NVARCHAR(20) OUTPUT,
	@n_cartonno		int OUTPUT,
	@c_button	   NVARCHAR(1),
	@b_success     int OUTPUT,
	@n_err         int OUTPUT,
	@c_errmsg      NVARCHAR(255) OUTPUT
) 
AS
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
/* 25 March 2004 WANYT Timberland FBR#20720: RF Stock Take Entry */
	declare @n_continue  		int,
		@n_starttcnt 		      int,
		@local_n_err 		      int,
		@local_c_errmsg 	      NVARCHAR(255),
		@n_cnt       		      int,
		@n_rowcnt       	      int,
		@c_authority		      NVARCHAR(30),
		@c_vat			         NVARCHAR(18),
		@n_odd			         int,
		@n_even			         int,
		@n_totalodd		         int,
		@n_totaleven		      int,
		@n_checkdigit		      int,
		@b_resultset		      int,
		@n_batch		            int,
		@c_SQL                NVARCHAR(2000), --NJOW02
		@c_PickSlipNo         NVARCHAR(10) --NJOW02
		
   DECLARE
      @cIdentifier            NVARCHAR( 2),
      @cPacktype              NVARCHAR( 1),
      @cSUSR1                 NVARCHAR( 20),
      @nCheckDigit            INT,
      @nTotalCnt              INT,
      @nTotalOddCnt           INT,
      @nTotalEvenCnt          INT,
      @nAdd                   INT,
      @nDivide                INT,
      @nRemain                INT,
      @nOddCnt                INT,
      @nEvenCnt               INT,
      @nOdd                   INT,
      @nEven                  INT

   DECLARE       
      @c_nCounter             NVARCHAR( 25)

	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
	       @local_n_err = 0, @local_c_errmsg = ''
	       
	--NJOW02
	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
		 EXECUTE nspGetRight null,	
       @c_StorerKey, 		      -- Storerkey
       '',				            -- Sku
       'GenLabelNo_SP', 	-- Configkey
       @b_success		OUTPUT,
       @c_authority	OUTPUT, 
       @n_err		   OUTPUT,
       @c_errmsg		OUTPUT

     IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_authority) AND type = 'P')
     BEGIN       
     	
     	 SELECT TOP 1 @c_PickslipNo = PickHeaderkey
     	 FROM PICKHEADER (NOLOCK)
     	 WHERE Orderkey = @c_Orderkey     	

       SET @c_SQL = 'EXEC ' + @c_authority + ' @c_PickSlipNo, @n_CartonNo, @c_LabelNo OUTPUT'

       EXEC sp_executesql @c_SQL 
          ,  N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_LabelNo NVARCHAR(20) OUTPUT' 
          ,  @c_PickSlipNo
          ,  0  
          ,  @c_labelno OUTPUT
                            
       GOTO EXIT_SP
     END
     ELSE
        SET @c_authority = ''  
	END       

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN	
      EXECUTE nspGetRight null,	
       @c_StorerKey, 		      -- Storerkey
       '',				            -- Sku
       'GenUCCLabelNoConfig', 	-- Configkey
       @b_success		OUTPUT,
       @c_authority	OUTPUT, 
       @n_err		   OUTPUT,
       @c_errmsg		OUTPUT

		IF @b_success <> 1
		BEGIN
			SELECT @n_continue = 3, @c_errmsg = 'nsp_GenLabelNo' + dbo.fnc_RTrim(@c_errmsg)
		END

		IF (@n_continue = 1 OR @n_continue = 2) 
		BEGIN	
			IF  @c_authority = '1'
			BEGIN
         	EXECUTE nspGetRight null,	
      	    @c_StorerKey, 		      -- Storerkey
      	    '',				            -- Sku
      	    'GenGenericUCCLabelNo', 	-- Configkey
      	    @b_success		OUTPUT,
      	    @c_authority	OUTPUT, 
      	    @n_err		   OUTPUT,
      		 @c_errmsg		OUTPUT
      
      		IF @b_success <> 1
      		BEGIN
      			SELECT @n_continue = 3, @c_errmsg = 'nsp_GenLabelNo' + dbo.fnc_RTrim(@c_errmsg)
      		END

            IF (@n_continue = 1 OR @n_continue = 2) AND @c_authority = '1'
            BEGIN
               SET @cIdentifier = '00'
               SET @cPacktype = '0'
               SET @c_LabelNo = ''
         
               SELECT @cSUSR1 = ISNULL(SUSR1, '0')
               FROM dbo.Storer WITH (NOLOCK)
               WHERE Storerkey = @c_StorerKey
               AND Type = '1'
         
               IF LEN(@cSUSR1) >= 9
               BEGIN
                  SET @n_continue = 3
                  SET @n_Err = 99999
                  SET @c_ErrMsg = 'Invld Barcode'
               END   -- IF LEN(@cSUSR1) >= 9

               IF (@n_continue = 1 OR @n_continue = 2)
               BEGIN
                  EXEC dbo.isp_getucckey
                        @c_StorerKey,
                        9,
                        @c_nCounter OUTPUT ,
                        @b_success  OUTPUT,
                        @n_err      OUTPUT,
                        @c_errmsg   OUTPUT,
                        0,
                        1
            
                  IF @b_success <> 1
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 99999
                     SET @c_ErrMsg = 'GenUCCKeyFail'
                  END

                  IF (@n_continue = 1 OR @n_continue = 2)
                  BEGIN
                     IF LEN(@cSUSR1) <> 8
                        SELECT @cSUSR1 = RIGHT('0000000' + CAST(@cSUSR1 AS VARCHAR( 7)), 7)
               
                     SET @c_LabelNo = @cIdentifier + @cPacktype + RTRIM(@cSUSR1) + RTRIM(@c_nCounter) --+ @nCheckDigit
               
                     SET @nOdd = 1
                     SET @nOddCnt = 0
                     SET @nTotalOddCnt = 0
                     SET @nTotalCnt = 0
         
                     WHILE @nOdd <= 20
                     BEGIN
                        SET @nOddCnt = CAST(SUBSTRING(@c_LabelNo, @nOdd, 1) AS INT)
                        SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
                        SET @nOdd = @nOdd + 2
                     END
               
                     SET @nTotalCnt = (@nTotalOddCnt * 3)
               
                     SET @nEven = 2
                     SET @nEvenCnt = 0
                     SET @nTotalEvenCnt = 0

                     WHILE @nEven <= 20
                     BEGIN
                        SET @nEvenCnt = CAST(SUBSTRING(@c_LabelNo, @nEven, 1) AS INT)
                        SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
                        SET @nEven = @nEven + 2
                     END
         
                     SET @nAdd = 0
                     SET @nRemain = 0
                     SET @nCheckDigit = 0
               
                     SET @nAdd = @nTotalCnt + @nTotalEvenCnt
                     SET @nRemain = @nAdd % 10
                     SET @nCheckDigit = 10 - @nRemain
               
                     IF @nCheckDigit = 10
                        SET @nCheckDigit = 0
               
                     SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
                  END
               END
            END -- GenUCCLabelNoConfig
            ELSE
            BEGIN
   				SELECT @c_vat = Vat
   				FROM STORER (NOLOCK)
   				WHERE STORERKEY = @c_storerkey
   
   				IF dbo.fnc_RTrim(@c_vat) IS NULL OR dbo.fnc_RTrim(@c_vat) = ''
   					SELECT @c_vat = '000000000'
   				
   				EXECUTE nspg_getkey
   					"TBLPackNo" ,
   					7 ,
   					@c_labelno   	OUTPUT ,
   					@b_success      = @b_success OUTPUT,
   					@n_err          = @n_err OUTPUT,
   					@c_errmsg       = @c_errmsg OUTPUT,
   					@b_resultset    = 0,
   					@n_batch        = 1
   				IF @b_success <> 1
   				BEGIN
   					SELECT @n_continue = 3, @c_errmsg = 'nsp_GenLabelNo' + dbo.fnc_RTrim(@c_errmsg)
   				END
   
   				IF (@n_continue = 1 OR @n_continue = 2) 
   				BEGIN	
   					SELECT @c_labelno = '00' + '0' + dbo.fnc_RTrim(@c_vat) + @c_labelno 
   					SELECT @n_odd = 1
   					SELECT @n_totalodd = 0, @n_totaleven = 0
   					
   					WHILE @n_odd <= 20
   					BEGIN
   						SELECT @n_totalodd = @n_totalodd + CONVERT(int, ISNULL(SUBSTRING(@c_labelno,@n_odd,1),0))
   						SELECT @n_odd = @n_odd + 2
   					END
   					
   					SELECT @n_totalodd = @n_totalodd * 3
   
   					SELECT @n_even = 2
   
   					WHILE @n_even <= 20
   					BEGIN
   						SELECT @n_totaleven = @n_totaleven + CONVERT(int, ISNULL(SUBSTRING(@c_labelno,@n_even,1),0))
   						SELECT @n_even = @n_even + 2
   					END
   
   					SELECT @n_checkdigit = 10 - ((@n_totalodd + @n_totaleven) % 10)
   					IF @n_checkdigit = 10 
   						SELECT @n_checkdigit = 0
   
   					SELECT @c_labelno = dbo.fnc_RTrim(@c_labelno) + dbo.fnc_LTrim(dbo.fnc_RTrim(STR(@n_checkdigit)))
   				END				
   			END
   		END
			ELSE
			BEGIN	
				EXECUTE nspg_getkey
					"PackNo" ,
					10 ,
					@c_labelno   	OUTPUT ,
					@b_success      = @b_success OUTPUT,
					@n_err          = @n_err OUTPUT,
					@c_errmsg       = @c_errmsg OUTPUT,
					@b_resultset    = 0,
					@n_batch        = 1

				IF @b_success <> 1
				BEGIN
					SELECT @n_continue = 3, @c_errmsg = 'nsp_GenLabelNo' + dbo.fnc_RTrim(@c_errmsg)
				END
			END 
		END
	END 
	
	IF (@n_continue = 1 OR @n_continue = 2) AND @c_button = '2' -- get cartonno for "close case"
	BEGIN
		
		SELECT @n_cartonno = ISNULL(CONVERT(INT,poduser),0) + 1
		FROM ORDERS (NOLOCK)
		WHERE orderkey = @c_orderkey
		
		--NJOW01 Start
		SELECT @n_cnt = ISNULL(COUNT(DISTINCT PACKDETAIL.Cartonno),0) + 1
		FROM PACKHEADER (NOLOCK)
		JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
		WHERE Orderkey = @c_Orderkey
		
		IF ISNULL(@n_cnt,0) > @n_cartonno
		   SET @n_cartonno = @n_cnt
		--NJOW01 End

		UPDATE ORDERS
		SET TrafficCop = NULL,
			PODUser = CONVERT(char(18), @n_cartonno)
		WHERE OrderKey = @c_orderkey

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
	   IF @n_err <> 0
	   BEGIN
	      SELECT @n_continue = 3
	      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63527   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': CartonNo Update Failed. (ispRF_PickNPackConfirm)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	   END
	END

  EXIT_SP:

	IF @n_continue=3  -- error occured - process and return
	BEGIN
		SELECT @b_success = 0
		IF @@trancount = 1 and @@trancount > @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			WHILE @@trancount > @n_starttcnt
			BEGIN
				COMMIT TRAN
			END
		END
	
		SELECT @n_err = @local_n_err
		SELECT @c_errmsg = @local_c_errmsg
		EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_GenLabelNo"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		WHILE @@trancount > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
END

GO