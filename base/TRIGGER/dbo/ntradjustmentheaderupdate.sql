SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Trigger: ntrAdjustmentHeaderUpdate                                        */
/* Creation Date:                                                            */
/* Copyright: IDS                                                            */
/* Written by:                                                               */
/*                                                                           */
/* Purpose:  Adjustment Header Update Transaction                            */
/*                                                                           */
/* Input Parameters:                                                         */
/*                                                                           */
/* Output Parameters:                                                        */
/*                                                                           */
/* Return Status:                                                            */
/*                                                                           */
/* Usage:                                                                    */
/*                                                                           */
/* Local Variables:                                                          */
/*                                                                           */
/* Called By: When update records                                            */
/*                                                                           */
/* PVCS Version: 1.6                                                         */
/*                                                                           */
/* Version: 5.4                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date         Author    Ver  Purposes                                      */
/* 27-May-2005  YokeBeen       For NIKE Regional (NSC) Project. Remarked     */
/*                             Script transfered from ntrAdjustmentHeaderAdd */
/*                             Changed the trigger point of NSC into the     */
/*                             NSCLog upon Finalized.                        */
/*                             - (SOS#36136) (YokeBeen01)                    */
/* 18-Oct-2005  Shong          Move C4 Adj Interface from Add trigger to     */
/*                             Update trigger, C4 is using Finalize Adj Opt  */
/*                             -- (SOS#25798) (Shong01)                      */ 
/* 29-Nov-2005  Shong          Copy WTC Adj Interface from Add trigger to    */
/*                             Update trigger, WTC TH is using Finalize Adj  */
/*                             -- SOS#43448 (Shong02)                        */ 
/* 15-Feb-2006  Vicky          Added in ADJLOG Configkey for interface       */
/* 19-Oct-2006  MaryVong       Add in RDT compatible error messages          */
/* 28-Jun-2007  MaryVong       Remove dbo.fnc_RTRIM and dbo.fnc_LTRIM        */
/* 04-Jan-2009  TLTING         Update eidtwho and editdate (tlting01)        */
/* 26-Jan-2011  MCTang    1.2  FBR#191481 - Added new trigger point for POSM */
/*                             interface with Configkey = "VADJLOG". (MC01)  */
/* 13-Jan-2012  YTWan     1.3  Adjustment Email Notification - (Wan01)       */
/* 23 May 2012  TLTING02  1.4  DM integrity - add update editdate B4         */
/*                             TrafficCop                                    */  
/* 28-Oct-2013  TLTING    1.5  Review Editdate column update                 */ 
/* 27-Dec-2013  MCTang    1.6  Added new trigger point - ADJ2LOG for         */
/*                             Alternate. (MC02)                             */
/* 15-May-2015  MCTang    1.7  New Interface Trigger Points (MC03)           */
/* 27-Jul-2017  TLTING    1.7  SET Option                                    */
/*****************************************************************************/

CREATE TRIGGER [dbo].[ntrAdjustmentHeaderUpdate]
ON  [dbo].[ADJUSTMENT]
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

   DECLARE @b_Success int       -- Populated by calls to stored procedures - was the proc successful?
			, @n_err int           -- Error number returned by stored procedure or this trigger
			, @n_err2 int          -- For Additional Error Detection
			, @c_errmsg NVARCHAR(250)  -- Error message returned by stored procedure or this trigger
			, @n_continue int
			, @n_starttcnt int                -- Holds the current transaction count
			, @c_preprocess NVARCHAR(250)         -- preprocess
			, @c_pstprocess NVARCHAR(250)         -- post process
			, @n_cnt int
			, @c_NIKEREGITF NVARCHAR(1) 		-- (YokeBeen01)
			, @c_FinalizedFlag NVARCHAR(1) 	-- (YokeBeen01)
			, @c_Adjustmentkey NVARCHAR(10)	-- (YokeBeen01)
         , @c_C4ITF  NVARCHAR(1)           -- (Shong01) 
         , @c_WTCITF NVARCHAR(1)           -- (Shong02)
         , @c_NWITF  NVARCHAR(1)           -- (Shong02)
         , @c_ADJITF NVARCHAR(1)           -- (Vicky)
         , @c_authority_vadjitf NVARCHAR(1)-- (MC01)
         , @c_AdjStatusControl      NVARCHAR(30) --(Wan01)

   SELECT  @b_Success			= 0 
			, @n_err					= 0 
			, @n_err2				= 0 
			, @c_errmsg				= '' 
			, @n_continue			= 1 
			, @n_starttcnt			= @@TRANCOUNT 
			, @c_preprocess		= '' 
			, @c_pstprocess		= '' 
			, @n_cnt					= 0 
			, @c_NIKEREGITF		= ''  	-- (YokeBeen01)
			, @c_FinalizedFlag	= ''     -- (YokeBeen01) 
			, @c_Adjustmentkey	= ''		-- (YokeBeen01)

   SET @c_AdjStatusControl = 0   --(Wan01) 

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END
   
	-- tlting02
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
               Where INSERTED.AdjustmentKey = DELETED.AdjustmentKey
               AND ( INSERTED.FinalizedFlag <> 'Y' OR DELETED.FinalizedFlag <> 'Y' ) ) 
         AND ( @n_continue = 1 or @n_continue = 2)
         AND NOT UPDATE(EditDate)                 
   BEGIN
      UPDATE ADJUSTMENT SET TrafficCop = NULL, EditDate = GETDATE(), EditWho=SUSER_SNAME() 
      FROM ADJUSTMENT, INSERTED, DELETED
      WHERE ADJUSTMENT.AdjustmentKey=inserted.AdjustmentKey
      AND   INSERTED.AdjustmentKey =  DELETED.AdjustmentKey 
      AND ( DELETED.FinalizedFlag <> 'Y' OR INSERTED.FinalizedFlag <> 'Y' ) 
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62850 --66700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ADJUSTMENT. (ntrAdjustmentHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   /* #INCLUDE <TRAHU1.SQL> */
   /****************************************/
   /* DATE MODIFIED: 9.28.99		*/
   /* BY: WALLY				*/
   /* to validate required fields for	*/
   /* inventory adjustment interface	*/
   /****************************************/
   -- START 9.28.99
   -- Overwrite by SHONG on 12-Jul-2004, script copy from Add Trigger 


   DECLARE @b_ColumnsUpdated VARBINARY(1000)       --MC03
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()       --MC03
   
   
   If @n_continue = 1 or @n_continue = 2
   Begin
      Declare @c_primarykey	 NVARCHAR(10), 
              @c_adjtype		 NVARCHAR(3), 
              @c_adjrefno		 NVARCHAR(10), 
              @c_whseorigin	 NVARCHAR(6)
      Declare @c_facility		 NVARCHAR(5), 
              @c_old_facility	 NVARCHAR(5), 
              @c_old_storerkey NVARCHAR(15)
      Declare @b_check_type	 NVARCHAR(1), 
              @b_check_ref		 NVARCHAR(1), 
              @b_check_ref_isnum NVARCHAR(1), 
              @b_check_whse	 NVARCHAR(1)
      Declare @c_authority		 NVARCHAR(1), 
              @b_check_asn		 NVARCHAR(1),
              @c_storerkey		 NVARCHAR(15)

      Select  @c_primarykey		= '', 
              @c_old_facility		= '', 
              @c_old_storerkey	= ''

      While 1 = 1
      Begin
         Select TOP 1 @c_primarykey = Adjustmentkey, 
                @c_adjtype = Adjustmenttype, 
                @c_adjrefno = customerrefno, 
                @c_whseorigin = fromtowhse, 
                @c_facility = Facility, 
                @c_storerkey = Storerkey 
           From INSERTED
          Where INSERTED.Adjustmentkey > @c_primarykey
          Order by INSERTED.Adjustmentkey
         If @@rowcount = 0
         Begin
            Break
         End
         If @c_old_facility <> @c_facility or @c_old_storerkey <> @c_storerkey
         Begin
            Execute nspGetRight @c_facility,  -- Facility
                                @c_storerkey, -- Storer
                                null,         -- Sku
                                'ADJHDR - ADJ TYPE REQUIRED',      -- ConfigKey
                                @b_success    output, 
                                @c_authority  output, 
                                @n_err        output, 
                                @c_errmsg     output
            If @b_success <> 1
            Begin
               SELECT @n_continue = 3, @n_err = 62825               
               Select @c_errmsg = 'ntrAdjustmentHeaderUpdate :' + dbo.fnc_RTrim(@c_errmsg)
               Break
            End
            Else 
            Begin
               If @c_authority = '1'
                  Select @b_check_type = '1'
               Else
                  Select @b_check_type = '0'
            End
            Execute nspGetRight @c_facility,  -- Facility
                                @c_storerkey, -- Storer
                                null,       -- Sku
                                'ADJHDR - ADJ REF REQUIRED',      -- ConfigKey
                                @b_success    output, 
                                @c_authority  output, 
                                @n_err        output, 
                                @c_errmsg     output
            If @b_success <> 1
            Begin
               SELECT @n_continue = 3, @n_err = 62826               
               Select @c_errmsg = 'ntrAdjustmentHeaderUpdate :' + dbo.fnc_RTrim(@c_errmsg)
               Break
            End
            Else 
            Begin
               If @c_authority = '1'
                  Select @b_check_ref = '1'
               Else
                  Select @b_check_ref = '0'
            End
            Execute nspGetRight @c_facility,  -- Facility
                                @c_storerkey, -- Storer
                                null,       -- Sku
                                'ADJHDR - ADJ TYPE MUST NUM',      -- ConfigKey
                                @b_success    output, 
                                @c_authority  output, 
                                @n_err        output, 
                                @c_errmsg     output
            If @b_success <> 1
            Begin
               SELECT @n_continue = 3, @n_err = 62827               
               Select @c_errmsg = 'ntrAdjustmentHeaderUpdate :' + dbo.fnc_RTrim(@c_errmsg)
               Break
            End
            Else 
            Begin
               If @c_authority = '1'
                  Select @b_check_ref_isnum = '1'
               Else
                  Select @b_check_ref_isnum = '0'
            End
            Execute nspGetRight @c_facility,  -- Facility
                                @c_storerkey, -- Storer
                                null,       -- Sku
                                'ADJHDR - WHSE REQ IF TOA & BRA',      -- ConfigKey
                                @b_success    output, 
                                @c_authority  output, 
                                @n_err        output, 
                                @c_errmsg     output
            If @b_success <> 1
            Begin
               SELECT @n_continue = 3, @n_err = 62828               
               Select @c_errmsg = 'ntrAdjustmentHeaderUpdate :' + dbo.fnc_RTrim(@c_errmsg)
               Break
            End
            Else 
            Begin
               If @c_authority = '1'
                  Select @b_check_whse = '1'
               Else
                  Select @b_check_whse = '0'
            End
            Execute nspGetRight @c_facility,  -- Facility
                                @c_storerkey, -- Storer
                                null,       -- Sku
                                'ADJHDR - ASN# REQ IF 01',      -- ConfigKey
                                @b_success    output, 
                                @c_authority  output, 
                                @n_err        output, 
                                @c_errmsg     output
            If @b_success <> 1
            Begin
               SELECT @n_continue = 3, @n_err = 62829               
               Select @c_errmsg = 'ntrAdjustmentHeaderUpdate :' + dbo.fnc_RTrim(@c_errmsg)
               Break
            End
            Else 
            Begin
               If @c_authority = '1'
                  Select @b_check_asn = '1'
               Else
                  Select @b_check_asn = '0'
            End
         End
      
         If @b_check_type = '1' and dbo.fnc_RTrim(@c_adjtype) is null
         Begin
       		SELECT @n_continue = 3, @n_err = 62830 --50000
       		SELECT @c_errmsg = 'VALIDATION ERROR: Adjustment Type is Required.'
            Break
         End
      
         If @b_check_ref = '1' and dbo.fnc_RTrim(@c_adjrefno) is null
         Begin
      			SELECT @n_continue = 3, @n_err = 62831 --50000
      			SELECT @c_errmsg = 'VALIDATION ERROR: Adjustment Reference Number is Required.'
            Break
         End
      
         If @b_check_ref_isnum = '1' and isnumeric(@c_adjrefno) <> 1
         Begin
      			SELECT @n_continue = 3, @n_err = 62832 --50000
      			SELECT @c_errmsg = 'VALIDATION ERROR: Invalid Adjustment Reference Number. Characters Not Allowed.'
            Break
         End
      
         If @b_check_whse = '1' and dbo.fnc_RTrim(@c_whseorigin) is null and @c_adjtype in ('TOA', 'BRA')
         Begin
      			SELECT @n_continue = 3, @n_err = 62833 --50000
      			SELECT @c_errmsg = 'VALIDATION ERROR: Warehouse Origin is Required.'
            Break
         End
      
         If @b_check_asn = '1' and @c_adjtype = '01' and 
            (dbo.fnc_RTrim(@c_adjrefno) is null or not exists(Select 1 from receipt (nolock) where receiptkey = @c_adjrefno))
         Begin
      			SELECT @n_continue = 3, @n_err = 62834 --50000
      			select @c_errmsg = 'VALIDATION ERROR: Invalid Adjustment Reference No. (ReceiptKey).'
            Break
         End
      End
   End
   -- END 9.28.99
   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @c_FinalizeAdjustment NVARCHAR(1) -- Flag to see if overallocations are allowed.

      SELECT @c_StorerKey = StorerKey 
      FROM   INSERTED
      
		SELECT @b_success = 0
		
		EXECUTE nspGetRight NULL,	-- Facility 
				  @c_StorerKey,   	-- Storer
				  NULL,   				-- No Sku in this Case
				  'FinalizeAdjustment', -- ConfigKey
				  @b_success    		    output, 
				  @c_FinalizeAdjustment	 output, 
				  @n_err        		    output, 
				  @c_errmsg     		    output
	
		IF @b_success <> 1
		BEGIN
			SELECT @n_continue = 3 
			SELECT @n_err = 62835 --60119 --62311   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Retrieve Failed On GetRight. (ntrAdjustmentHeaderUpdate)"
		END
      ELSE IF @c_FinalizeAdjustment = '1'
      BEGIN
         IF EXISTS( SELECT 1 FROM DELETED WHERE FinalizedFlag = 'Y' )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 62836 --66800
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": UPDATE not allowed. (ntrAdjustmentHeaderUpdate)"
         END
      END
   END

   --(Wan01) - START
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 

      IF Update(FinalizedFlag) 
      BEGIN 
         IF EXISTS ( SELECT 1 FROM INSERTED
                     JOIN DELETED ON (INSERTED.AdjustmentKey = DELETED.AdjustmentKey)
                     JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'ADJApvMail') 
                                                    AND(INSERTED.Storerkey = @c_Storerkey)
                                                    AND(INSERTED.FinalizedFlag = CL.Short)
                     WHERE INSERTED.FinalizedFlag <> DELETED.FinalizedFlag ) -- Change Status
         BEGIN 
            EXECUTE dbo.nspGetRight NULL                 -- facility
                                 ,  @c_Storerkey         -- Storerkey
                                 ,  NULL                 -- Sku
                                 ,  'AdjStatusControl'   -- Configkey
                                 ,  @b_success      OUTPUT
                                 ,  @c_AdjStatusControl   OUTPUT
                                 ,  @n_err          OUTPUT
                                 ,  @c_errmsg       OUTPUT
            IF @b_success <> 1  
            BEGIN  
               SET @n_continue = 3 
               SET @n_Err = 62851
               SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err) 
                             + ': Error Getting StorerCongfig for Storer: ' + @c_Storerkey
                             + '. (ispWAVRL01)' 
            END  

            IF @c_AdjStatusControl = '1'
            BEGIN
               SELECT @c_Adjustmentkey = INSERTED.Adjustmentkey
                     ,@c_FinalizedFlag = INSERTED.FinalizedFlag
               FROM INSERTED

               EXEC ispGenTransmitLog3 'AdjStatusControl', @c_Adjustmentkey, @c_FinalizedFlag, @c_storerkey, ''  
                                    ,  @b_success OUTPUT  
                                    ,  @n_err OUTPUT  
                                    ,  @c_errmsg OUTPUT  
                 
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 62852     -- should be set to the sql errmessage but i don't know how to do so.  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 TableName (AdjStatusControl) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
               END 
            END
         END
      END
   END
   --(Wan01) - END  
   

-- (YokeBeen01) - Start
-- (Shong01) - Start 
	IF @n_continue = 1 OR @n_continue = 2 AND UPDATE(FinalizedFlag) 
	BEGIN
      DECLARE C_FinalizedAdj CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT INSERTED.Adjustmentkey, INSERTED.Storerkey, INSERTED.Adjustmenttype 
        FROM   INSERTED
        WHERE  FinalizedFlag = 'Y'

      OPEN C_FinalizedAdj 
      FETCH NEXT FROM C_FinalizedAdj INTO @c_Adjustmentkey, @c_Storerkey, @c_adjtype 

		WHILE @@FETCH_STATUS <> -1 
		BEGIN
			SELECT @c_NIKEREGITF = '0' 

			EXECUTE nspGetRight 
						NULL,					-- facility
						@c_storerkey, 		-- Storerkey
						NULL,					-- Sku
						'NIKEREGITF',		-- Configkey
						@b_success			OUTPUT,
						@c_NIKEREGITF		OUTPUT, 
						@n_err				OUTPUT,
						@c_errmsg			OUTPUT

			IF @b_success <> 1
			BEGIN
				SELECT @n_continue = 3, @n_err = 62837
				SELECT @c_errmsg = 'ntrAdjustmentHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
			END

			IF @c_NIKEREGITF = '1'
			BEGIN
            EXEC ispGenNSCLog 'NIKEREGADJ', @c_Adjustmentkey, '', @c_storerkey, ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
					SELECT @n_err = 62838 --63811   -- should be set to the sql errmessage but i don't know how to do so.
					SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into NSCLog Table (NIKEREGADJ) Failed. (ntrAdjustmentHeaderUpdate)'
            END

            GOTO FETCH_NEXT 
			END -- @c_NIKEREGITF = '1'

         IF @n_continue = 1 OR @n_continue = 2 
         BEGIN 
   			SELECT @c_C4ITF = '0' 
   
   			EXECUTE nspGetRight 
   				NULL,					-- facility
   				@c_storerkey, 		-- Storerkey
   				NULL,					-- Sku
   				'C4ITF',	         -- Configkey
   				@b_success			OUTPUT,
   				@c_C4ITF		      OUTPUT, 
   				@n_err				OUTPUT,
   				@c_errmsg			OUTPUT
   
   			IF @b_success <> 1
   			BEGIN
   				SELECT @n_continue = 3, @n_err = 62839
   				SELECT @c_errmsg = 'ntrAdjustmentHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
   			END
   
            IF @c_C4ITF = '1'
            BEGIN	
               -- Insert a record into TransmitLog2 table
   				IF @c_adjtype = '01' 
   				BEGIN
   	            EXEC ispGenTransmitLog2 'C4ADJ01', @c_Adjustmentkey, '', @c_Storerkey, ''
   	            , @b_success OUTPUT
   	            , @n_err OUTPUT
   	            , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
         				SELECT @n_err = 62840 --63811   -- should be set to the sql errmessage but i don't know how to do so.
         				SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog2 Table (C4ADJ01) Failed. (ntrAdjustmentHeaderUpdate)'
                  END
   				END
   				ELSE IF @c_adjtype NOT IN ('01','10')
               BEGIN				               
                  EXEC ispGenTransmitLog2 'C4ADJ', @c_Adjustmentkey, '', @c_Storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
         				SELECT @n_err = 62841 --63811   -- should be set to the sql errmessage but i don't know how to do so.
         				SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog2 Table (C4ADJ) Failed. (ntrAdjustmentHeaderUpdate)'
                  END                  
               END      
               GOTO FETCH_NEXT 
            END -- @c_C4ITF = '1'
         END -- @n_continue = 1 
   
         -- Added By Vicky on 15-Feb-2006 (Generic) - Start
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @c_ADJITF = '0' 

            EXECUTE nspGetRight 
	            NULL,					-- facility
	            @c_Storerkey, 		-- Storerkey
	            NULL,					-- Sku
	            'ADJLOG',	      -- Configkey
	            @b_success			OUTPUT,
	            @c_ADJITF		   OUTPUT, 
	            @n_err				OUTPUT,
	            @c_errmsg			OUTPUT

            IF @b_success <> 1
            BEGIN
	            SELECT @n_continue = 3, @n_err = 62842
	            SELECT @c_errmsg = 'ntrAdjustmentHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            END

            IF @c_ADJITF = '1'
            BEGIN	
         		
               -- Insert a record into TransmitLog3 table
               EXEC ispGenTransmitLog3 'ADJLOG', @c_Adjustmentkey, '', @c_Storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
         	
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
		            SELECT @n_err = 62843 --63811   -- should be set to the sql errmessage but i don't know how to do so.
		            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (ADJLOG) Failed. (ntrAdjustmentHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
              END -- @c_ADJITF = '1'
         END -- IF @n_continue = 1 
         -- Added By Vicky on 15-Feb-2006 (Generic) - End

         -- (MC02) - S
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @c_ADJITF = '0' 

            EXECUTE nspGetRight 
	            NULL,             -- facility
	            @c_Storerkey,     -- Storerkey
	            NULL,             -- Sku
	            'ADJ2LOG',        -- Configkey
	            @b_success			OUTPUT,
	            @c_ADJITF		   OUTPUT, 
	            @n_err				OUTPUT,
	            @c_errmsg			OUTPUT

            IF @b_success <> 1
            BEGIN
	            SELECT @n_continue = 3, @n_err = 62842
	            SELECT @c_errmsg = 'ntrAdjustmentHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
            END

            IF @c_ADJITF = '1'
            BEGIN	
         		
               -- Insert a record into TransmitLog3 table
               EXEC ispGenTransmitLog3 'ADJ2LOG', @c_Adjustmentkey, '', @c_Storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
         	
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
		            SELECT @n_err = 62843 --63811   -- should be set to the sql errmessage but i don't know how to do so.
		            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (ADJ2LOG) Failed. (ntrAdjustmentHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
              END -- @c_ADJITF = '1'
         END -- IF @n_continue = 1 
         -- (MC02) - E

         -- (MC01) - Start 
      	IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0
            SELECT @c_authority_vadjitf = '0'

            EXECUTE dbo.nspGetRight  '',   -- Facility
                     @c_StorerKey,         -- Storer
                     '',                   -- Sku
                     'VADJLOG',            -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_vadjitf  OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1 
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63801  
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) 
                                + ': Retrieve of Right (VADJLOG) Failed (ntrAdjustmentHeaderUpdate) ( SQLSvr MESSAGE=' 
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
            ELSE 
            BEGIN 
               IF @c_authority_vadjitf = '1' 
               BEGIN

                  EXEC dbo.ispGenVitalLog  'VADJLOG', @c_Adjustmentkey, '', @c_Storerkey, ''
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT 

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 62843
		               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) 
                                      + ': Insert Into VITALLOG Table (ADJLOG) Failed. (ntrAdjustmentHeaderUpdate) ( SQLSvr MESSAGE=' 
                                      + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END -- @c_authority_vadjitf = '1' 
            END -- IF @b_success = 1
         END 
         -- (MC01) - End 

         -- (Shong02) Start
         -- Added By MaryVong on 25-Jun-2004 (SOS#43448)- Start
      	IF @n_continue = 1 OR @n_continue = 2
      	BEGIN
            SELECT @c_WTCITF = '0' 
   
   			EXECUTE nspGetRight 
   				NULL,					-- facility
   				@c_storerkey, 		-- Storerkey
   				NULL,					-- Sku
   				'WTCInterface',	-- Configkey
   				@b_success			OUTPUT,
   				@c_WTCITF		   OUTPUT, 
   				@n_err				OUTPUT,
   				@c_errmsg			OUTPUT

   			IF @b_success <> 1
   			BEGIN
   				SELECT @n_continue = 3, @n_err = 62844
   				SELECT @c_errmsg = 'ntrAdjustmentHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
   			END
	
   			IF @c_WTCITF = '1' AND dbo.fnc_RTrim(@c_adjtype) <> '10'  -- SOS25581 No interface if adjtype='10'
   			BEGIN
               -- Insert a record into TransmitLog2 table
               EXEC ispGenTransmitLog2 'WTCADJ', @c_Adjustmentkey, '', @c_storerkey, ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT
   
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
   					SELECT @n_err = 62845 --63811   -- should be set to the sql errmessage but i don't know how to do so.
   					SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Unable To Obtain TransmitLog2Key. (ntrAdjustmentHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               GOTO FETCH_NEXT 
   		   END -- @c_WTCITF = '1'
         END -- IF @n_continue = 1 
      	IF @n_continue = 1 OR @n_continue = 2
      	BEGIN
   			SELECT @c_NWITF = '0' 
   
   			EXECUTE nspGetRight 
   				NULL,					-- facility
   				@c_storerkey, 		-- Storerkey
   				NULL,					-- Sku
   				'NWInterface',		-- Configkey
   				@b_success			OUTPUT,
   				@c_NWITF		      OUTPUT, 
   				@n_err				OUTPUT,
   				@c_errmsg			OUTPUT

   			IF @b_success <> 1
   			BEGIN
   				SELECT @n_continue = 3, @n_err = 62846
   				SELECT @c_errmsg = 'ntrAdjustmentHeaderUpdate' + dbo.fnc_RTrim(@c_errmsg)
   			END
	
   			IF @c_NWITF = '1'
   			BEGIN
               -- Insert a record into TransmitLog2 table
   				IF @c_adjtype = '01' 
   				BEGIN
   					-- SOS27626
   	            -- EXEC ispGenTransmitLog2 'NWINVADJ01', @c_Adjustmentkey, '', @c_storerkey, ''
   	            EXEC ispGenTransmitLog3 'NWINVADJ01', @c_Adjustmentkey, '', @c_storerkey, ''
   	            , @b_success OUTPUT
   	            , @n_err OUTPUT
   	            , @c_errmsg OUTPUT
   	            
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
      					SELECT @n_err = 62847 --63811   -- should be set to the sql errmessage but i don't know how to do so.
      					SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (NWINVADJ01) Failed. (ntrAdjustmentHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END   	            
   				END
   				ELSE
               BEGIN				           
               	-- SOS27626    
                  -- EXEC ispGenTransmitLog2 'NWINVADJ', @c_Adjustmentkey, '', @c_storerkey, ''
                  EXEC ispGenTransmitLog3 'NWINVADJ', @c_Adjustmentkey, '', @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
      					SELECT @n_err = 62848 --63811   -- should be set to the sql errmessage but i don't know how to do so.
      					SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (NWINVADJ) Failed. (ntrAdjustmentHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  END
               END
               GOTO FETCH_NEXT 
   			END -- @c_NWITF = '1'
          END -- IF @n_continue = 1 

         -- Added By Shong on 29-Nov-2005 (IDSTH - WTC) - (SOS#43448)
         -- (Shong02) Complete

         FETCH_NEXT:
         FETCH NEXT FROM C_FinalizedAdj INTO @c_Adjustmentkey, @c_Storerkey, @c_adjtype  

		END -- While Loop 
      CLOSE C_FinalizedAdj
      DEALLOCATE C_FinalizedAdj 
	END -- IF @n_continue = 1 
-- (YokeBeen01) - End
-- (Shong01) - End 

   -- (MC03) - S  
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (Start)   */  
   /********************************************************/  
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN        
      DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT INS.AdjustmentKey
           , INS.StorerKey
      FROM   INSERTED INS 
      JOIN   ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
      WHERE  ITC.SourceTable = 'ADJUSTMENT'  
      AND    ITC.sValue      = '1'       

      OPEN Cur_TriggerPoints  
      FETCH NEXT FROM Cur_TriggerPoints INTO @c_AdjustmentKey, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         EXECUTE dbo.isp_ITF_ntrAdjustment  
                  @c_TriggerName    = 'ntrAdjustmentHeaderUpdate'
                , @c_SourceTable    = 'ADJUSTMENT'  
                --, @c_Storerkey      = @c_Storerkey
                , @c_AdjustmentKey  = @c_AdjustmentKey  
                , @b_ColumnsUpdated = @b_ColumnsUpdated    
                , @b_Success        = @b_Success   OUTPUT  
                , @n_err            = @n_err       OUTPUT  
                , @c_errmsg         = @c_errmsg    OUTPUT  

         FETCH NEXT FROM Cur_TriggerPoints INTO @c_AdjustmentKey, @c_Storerkey
      END -- WHILE @@FETCH_STATUS <> -1  
      CLOSE Cur_TriggerPoints  
      DEALLOCATE Cur_TriggerPoints  
   END -- IF @n_continue = 1 OR @n_continue = 2   
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (End)     */  
   /********************************************************/  
   -- (MC03) - E
   
   /* #INCLUDE <TRAHU2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      IF @n_IsRDT = 1
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
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrAdjustmentHeaderUpdate'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN   
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END


GO