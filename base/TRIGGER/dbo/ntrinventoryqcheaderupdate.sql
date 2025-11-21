SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrInventoryQCHeaderUpdate                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  InventoryQC Header Update Transaction                      */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When update records                                       */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 08-Jul-2005  Vicky     1.0   Add IQCLOG as Configkey for Interface   */
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()     */
/* 03-Nov-2010  YokeBeen  1.2   FBR#195030 - Added new trigger point    */
/*                              for WITRON interface with               */
/*                              Configkey = "WTNIQCLOG". - (YokeBeen01) */
/* 26-Jan-2011  MCTang    1.3   FBR#191481 - Added new trigger point for*/
/*                              POSM interface with Configkey =         */
/*                              "VIQCLOG". (MC01)                       */
/* 23 May 2012  TLTING02  1.4   DM integrity - add update editdate B4   */
/*                              TrafficCop for status <> 'Y'            */ 
/* 28-Oct-2013  TLTING    1.5   Review Editdate column update           */  
/* 27-Dec-2013  MCTang    1.6  Added new trigger point - IQC2LOG for    */
/*                             Alternate. (MC01)                        */
/* 15-May-2015  MCTang    1.7  New Interface Trigger Points (MC02)      */
/************************************************************************/

CREATE TRIGGER ntrInventoryQCHeaderUpdate 
ON InventoryQC
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END   
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_success  int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err      int       -- Error number returned by stored procedure or this trigger  
         , @c_errmsg   NVARCHAR(250) -- Error message returned by stored procedure or this trigger 
         , @n_continue int                 /* continuation flag 
	                                             1=Continue
	                                             2=failed but continue processsing 
	                                             3=failed do not continue processing 
	                                             4=successful but skip furthur processing */
         , @n_starttcnt int                -- Holds the current transaction count                                               
         , @n_cnt       int                      /* variable to hold @@ROWCOUNT */ 
   /****28 Sept 2004 YTWan - FBR_JAMO011-Outbound-Kitting Receipt Confirmation****/
   /****28 Sept 2004 YTWan - FBR_JAMO008-Stock Movement Outbound****/

   DECLARE	@c_MSFITF                 NVARCHAR(1)      -- SOS30125 MAXXIUM IQC Confirmation
          , @c_authority_wtniqcitf    NVARCHAR(1)      -- (YokeBeen01)
          , @c_authority_viqcitf      NVARCHAR(1)      -- (MC01)
          , @c_IQCKey                 NVARCHAR(10)     -- (MC02)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   -- TLTING02
   IF  EXISTS ( SELECT 1 FROM INSERTED, DELETED
                Where INSERTED.QC_Key = DELETED.QC_Key
                 AND ( INSERTED.FinalizeFlag <> 'Y' OR DELETED.FinalizeFlag <> 'Y' ) )
        AND ( @n_continue = 1 or @n_continue=2 )          
        AND NOT UPDATE(EditDate)         
   BEGIN
      UPDATE InventoryQC WITH (ROWLOCK)
         SET EditDate = GETDATE(),
             EditWho = SUSER_SNAME()
        FROM InventoryQC, INSERTED
       WHERE InventoryQC.QC_Key = INSERTED.QC_Key
       AND   InventoryQC.FinalizeFlag <> 'Y'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=63817   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                          + ': Update Editdate/User Failed On Table InventoryQC. (ntrInventoryQCHeaderUpdate) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   
   IF NOT UPDATE(FinalizeFlag) AND NOT UPDATE(RefNo)
   BEGIN
      SELECT @n_continue = 4     -- No Error But Skip Processing
   END

   DECLARE @b_ColumnsUpdated VARBINARY(1000)       --MC02
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()       --MC02

   IF @n_continue = 1 OR @n_continue = 2 
   BEGIN
      DECLARE @c_QCKey        NVARCHAR(10)
            , @c_Storerkey    NVARCHAR(20)
            , @c_finalizeflag NVARCHAR(1)
            , @c_type         NVARCHAR(10)

      SELECT @c_QCKey = IQC.QC_Key,
             @c_Storerkey = IQC.Storerkey,
             @c_finalizeflag = IQC.FinalizeFlag,
             @c_type = IQC.Reason
        FROM InventoryQC IQC WITH (NOLOCK), INSERTED,  DELETED
       WHERE IQC.QC_Key = INSERTED.QC_Key
         AND INSERTED.QC_Key = DELETED.QC_Key

      -- Generate Interface File Here................
      IF @c_finalizeflag = 'Y'
      BEGIN
         -- 24 Sept 2004 YTWan - FBR_JAMO011-Outbound-Kitting Receipt Confirmation - START
         IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey
                        AND ConfigKey = 'FinalizeIQC' AND sValue = '1' )
         BEGIN
            IF @c_type = 'WHKITRCP'
            BEGIN
               EXEC ispGenTransmitLog2 'JAMOKITRCP', @c_QCKey , '', @c_Storerkey , ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            ELSE
            BEGIN
               IF @c_type = 'JAMOMOVE'
               BEGIN
                  EXEC ispGenTransmitLog2 'JAMOIQCMV', @c_QCKey , '', @c_Storerkey , ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT		

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
            END
         END -- Valid StorerConfig,  OrderType
         -- 24 Sept 2004 YTWan - FBR_JAMO011 -Outbound-Kitting Receipt Confirmation - END

         -- Added By Vicky 08 July 2005 - Start IQCLOG
         IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey
                        AND ConfigKey = 'IQCLOG' AND sValue = '1' )
         BEGIN
            EXEC ispGenTransmitLog3 'IQCLOG', @c_QCKey, '', @c_Storerkey, '' 
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=63811   
               SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                                + ': Unable To Obtain LogKey. (ntrInventoryQCHeaderUpdate) ( sqlsvr message=' 
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- IQCLOG = '1' -- Added By Vicky 08 July 2005 - End IQCLOG

         -- (MC01) - S
         IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey
                        AND ConfigKey = 'IQC2LOG' AND sValue = '1' )
         BEGIN
            EXEC ispGenTransmitLog3 'IQC2LOG', @c_QCKey, '', @c_Storerkey, '' 
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=63811   
               SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                                + ': Unable To Obtain LogKey. (ntrInventoryQCHeaderUpdate) ( sqlsvr message=' 
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END 
         -- (MC01) - E

         -- (YokeBeen01) - Start 
         SELECT @b_success = 0
         EXECUTE dbo.nspGetRight  '',   -- Facility
                  @c_StorerKey,         -- Storer
                  '',                   -- Sku
                  'WTNIQCLOG',          -- ConfigKey
                  @b_success               OUTPUT,
                  @c_authority_wtniqcitf   OUTPUT,
                  @n_err                   OUTPUT,
                  @c_errmsg                OUTPUT

         IF @b_success <> 1 
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63812  
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                             + ': Retrieve of Right (WTNIQCLOG) Failed (ntrInventoryQCHeaderUpdate) ( SQLSvr MESSAGE=' 
                             + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
         ELSE 
         BEGIN 
            IF @c_authority_wtniqcitf = '1' 
            BEGIN
               EXEC dbo.ispGenWitronLog 'WTNIQCLOG', @c_QCKey, '', @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- @c_authority_wtniqcitf = '1' 
         END -- IF @b_success = 1 
         -- (YokeBeen01) - End 

         -- (MC01) - Start 
      	IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            SELECT @c_authority_viqcitf = '0'

            EXECUTE dbo.nspGetRight  '',   -- Facility
                     @c_StorerKey,         -- Storer
                     '',                   -- Sku
                     'VIQCLOG',            -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_viqcitf  OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1 
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63801  
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                                + ': Retrieve of Right (VIQCLOG) Failed (ntrInventoryQCHeaderUpdate) ( SQLSvr MESSAGE=' 
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            ELSE 
            BEGIN 
               IF @c_authority_viqcitf = '1' 
               BEGIN

                  EXEC dbo.ispGenVitalLog  'VIQCLOG', @c_QCKey, '', @c_Storerkey, ''
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT 

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 62843
		               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) 
                                      + ': Insert Into VITALLOG Table (VIQCLOG) Failed. (ntrInventoryQCHeaderUpdate) ( SQLSvr MESSAGE=' 
                                      + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- @c_authority_viqcitf = '1' 
            END -- IF @b_success = 1
         END 
         -- (MC01) - End

      END -- @c_finalizeflag = 'Y'
   END 

   -- Added by MaryVong on 21Dec2004 (SOS30125 MAXXIUM IQC Confirmation)
   -- As per user request, IQC record is created, wait for permit, so user will only update RefNo 1 hr after
   -- record is created. There is no finalizeflag setting for Maxxium
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      IF UPDATE(RefNo)
      BEGIN
         SELECT @c_MSFITF = 0, @b_success = 0 

         EXECUTE nspGetRight NULL,	-- facility
                  @c_Storerkey, 		-- Storerkey
                  NULL,					-- Sku
                  'MSFITF',		      -- Configkey
                  @b_success OUTPUT,
                  @c_MSFITF 	OUTPUT,
                  @n_err 		OUTPUT,
                  @c_errmsg 	OUTPUT
	
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = 'ntrInventoryQCHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
         END
         ELSE IF @c_MSFITF = '1'
         BEGIN
            -- Only export if IQCType with Short='MSFITF'
            IF (SELECT Short FROM CODELKUP WITH (NOLOCK) WHERE ListName ='IQCTYPE' 
                   AND Code = @c_type) = 'MSFITF'
            BEGIN
               SELECT @b_success = 1
               EXEC ispGenTransmitLog2 'IQCMSF', @c_QCKey, '', @c_Storerkey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=63813   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg ='NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                                   + ': Unable to obtain transmitlogkey (ntrInventoryQCHeaderUpdate) ( SQLSvr MESSAGE=' 
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
         END -- Valid StorerConfig
      END -- IF UPDATE(RefNo) 
   END -- continue 			
   -- End of SOS30125

   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate) 
   BEGIN
      UPDATE InventoryQC WITH (ROWLOCK)
         SET EditDate = GETDATE(),
             EditWho = SUSER_SNAME()
        FROM InventoryQC, INSERTED
       WHERE InventoryQC.QC_Key = INSERTED.QC_Key
       AND INSERTED.FinalizeFlag = 'Y'               -- TLTING02

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),ISNULL(@n_err,0)), @n_err=63814   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0)) 
                          + ': Update Editdate/User Failed On Table InventoryQC. (ntrInventoryQCHeaderUpdate) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   -- (MC02) - S  
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (Start)   */  
   /********************************************************/  
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN        
      DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT INS.QC_Key
           , INS.StorerKey
      FROM   INSERTED INS 
      JOIN   ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
      WHERE  ITC.SourceTable = 'InventoryQC'  
      AND    ITC.sValue      = '1'       

      OPEN Cur_TriggerPoints  
      FETCH NEXT FROM Cur_TriggerPoints INTO @c_IQCKey, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         EXECUTE dbo.isp_ITF_ntrIQC  
                  @c_TriggerName    = 'ntrInventoryQCHeaderUpdate'
                , @c_SourceTable    = 'InventoryQC'  
                --, @c_Storerkey      = @c_Storerkey
                , @c_IQCKey         = @c_IQCKey  
                , @b_ColumnsUpdated = @b_ColumnsUpdated    
                , @b_Success        = @b_Success   OUTPUT  
                , @n_err            = @n_err       OUTPUT  
                , @c_errmsg         = @c_errmsg    OUTPUT  

         FETCH NEXT FROM Cur_TriggerPoints INTO @c_IQCKey, @c_Storerkey
      END -- WHILE @@FETCH_STATUS <> -1  
      CLOSE Cur_TriggerPoints  
      DEALLOCATE Cur_TriggerPoints  
   END -- IF @n_continue = 1 OR @n_continue = 2   
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (End)     */  
   /********************************************************/  
   -- (MC02) - E

   SET ROWCOUNT 0
   SET NOCOUNT OFF
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

      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrInventoryQCHeaderUpdate'
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