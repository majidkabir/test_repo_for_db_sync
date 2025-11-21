SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrStocktakeparametersUpdate                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When Udpating Stocktakeparameters Record                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 14-Dec-2005  Shong    1.0  Include StockTakeParameter into Archive CC*/
/* 07-Nov-2006  June     1.0  SOS55261 - Disallow Change of Stocktake   */
/*                            Parameters when CCDetail exists           */
/* 20-Sep-2010  MC       1.1  SOS187913 - Add STKTAKELOG as Configkey   */
/*                            for Interface (MC01)                      */
/* 28-Oct-2013  TLTING   1.2  Review Editdate column update             */
/************************************************************************/
CREATE TRIGGER ntrStocktakeparametersUpdate
ON Stocktakesheetparameters
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue       int,  
            @n_starttcnt      int,
            @c_pwd            NVARCHAR(10),
            @c_storerkey      NVARCHAR(20),
            @c_cckey          NVARCHAR(10),
            @c_transmitlogkey NVARCHAR(10),
            @c_authority      NVARCHAR(1),
            @b_success        int,
            @n_err            int,
            @c_errmsg         NVARCHAR(250)
         
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

	-- Start : SOS55261                            
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN   
      SELECT @c_cckey = StockTakeKey
      FROM   INSERTED

		IF  NOT UPDATE(Protect) AND NOT UPDATE(Password)
		AND NOT UPDATE(FinalizeStage) AND NOT UPDATE(PopulateStage) 
		AND NOT UPDATE(AdjReasonCode) AND NOT UPDATE(AdjType)
		BEGIN
			IF EXISTS (SELECT 1 FROM CCDETAIL (NOLOCK) WHERE CCKEY = @c_cckey)
			BEGIN
			   SELECT @n_continue=3
			   SELECT @c_errmsg= CONVERT(char(250), @n_err), @n_err=99701
			   SELECT @c_errmsg= "NSQL"+CONVERT(char(5), @n_err)+":Change Of Stock Take Parameters Not Allow When CCDETAILS Exists. (ntrStocktakeparametersUpdate)"+"("+"SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+")"
			END
		END
	END
	-- End : SOS55261
	   
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN   

      IF UPDATE(Password)
      BEGIN

         SELECT @c_pwd = Password, 
                @c_Storerkey = Storerkey,
                @c_cckey = StockTakeKey
         FROM   INSERTED

         IF @c_pwd = 'POSTED'
         BEGIN
            Select @b_success = 0      
            Execute nspGetRight null, 
                                @c_StorerKey,   -- Storer
                                null,         -- Sku
                                'TBLHKITF',             -- ConfigKey
                                @b_success          output, 
                                @c_authority        output, 
                                @n_err              output, 
                                @c_errmsg           output
            If @b_success = 1 AND @c_authority = '1'
            Begin
               IF NOT EXISTS (SELECT 1 FROM TransmitLog2 (NOLOCK) WHERE TableName = 'TBLSTOCK' 
                              AND    Key1 = @c_cckey
                              AND    Key3 = @c_Storerkey)
               BEGIN
                  EXECUTE nspg_getkey
                  'TransmitlogKey2'
                  ,10
                  , @c_transmitlogkey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
      
                  IF NOT @b_success=1
                  BEGIN
                     SELECT @n_continue=3
                  END
      
                  IF @n_continue = 1 or @n_continue = 2 
                  BEGIN
                     INSERT TransmitLog2 (transmitlogkey,tablename,key1,key2, key3)
                     VALUES (@c_transmitlogkey, 'TBLSTOCK', @c_cckey, '', @c_storerkey)
                     SELECT @n_err= @@Error
                     IF NOT @n_err=0
                     BEGIN
                        SELECT @n_continue=3
                        Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=99701
                        Select @c_errmsg= "NSQL"+CONVERT(char(5), @n_err)+":Insert failed on TransmitLog. (ntrStocktakeparametersUpdate)"+"("+"SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+")"
                     END 
                  END
               END -- TBLSTOCK
            End -- TBLITF

            -- MC01 Start
            IF @n_continue = 1 or @n_continue = 2 
            BEGIN
               
               Select @b_success = 0      
               Execute nspGetRight null, 
                                   @c_StorerKey,-- Storer
                                   null,        -- Sku
                                   'STKTAKELOG',-- ConfigKey
                                   @b_success   OUTPUT, 
                                   @c_authority OUTPUT, 
                                   @n_err       OUTPUT, 
                                   @c_errmsg    OUTPUT

               IF @b_success = 1 AND @c_authority = '1'
               BEGIN  
                    EXEC ispGenTransmitLog3 'STKTAKELOG', @c_CCKey, '', @c_Storerkey, ''   
                       , @b_success OUTPUT  
                       , @n_err OUTPUT  
                       , @c_errmsg OUTPUT  
               END
            END
            -- MC01 End
         END -- POSTED
      END -- Password
   END 
   


   -- Added by SHONG on 31-OCT-2003
   -- Update the EditDate and EditWho
   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE Stocktakesheetparameters
         SET EditDate = GetDate(),
             EditWho  = SUser_SName()
      FROM INSERTED
      WHERE Stocktakesheetparameters.StockTakeKey = INSERTED.StockTakeKey
   
   END
   
   /* Return Statement */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
       IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt 
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
       execute nsp_logerror @n_err, @c_errmsg, "ntrStocktakeparametersUpdate"
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
       RETURN
   END
   ELSE
   BEGIN
   /* Error Did Not Occur , Return Normally */
       WHILE @@TRANCOUNT > @n_starttcnt 
       BEGIN
            COMMIT TRAN
       END
       RETURN
   END
  /* End Return Statement */
END








GO