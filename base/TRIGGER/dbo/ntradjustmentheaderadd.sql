SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Trigger: ntrAdjustmentHeaderAdd                                          */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose:  Adjustment Header Add Transaction                              */
/*                                                                          */
/* Input Parameters:                                                        */
/*                                                                          */
/* Output Parameters:                                                       */
/*                                                                          */
/* Return Status:                                                           */
/*                                                                          */
/* Usage:                                                                   */
/*                                                                          */
/* Local Variables:                                                         */
/*                                                                          */
/* Called By: When records add                                              */
/*                                                                          */
/* PVCS Version: 1.4                                                        */
/*                                                                          */
/* Version: 6.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author    Ver  Purposes                                     */
/* 06-Nov-2002  Leo Ny         Program rewrite for IDS version 5            */
/* 17-Oct-2003  YokeBeen       For NIKE Regional (NSC) Project              */
/*                             - (SOS#15352) (YokeBeen01)                   */
/* 20-Feb-2004  YokeBeen       For NIKE Regional (NSC) Project - Changed to */
/*                             trigger records into NSCLog table with       */
/*                             'NSCKEY'. - (SOS#20000) (YokeBeen02)         */
/* 13-Jul-2004  YokeBeen       Commended Script transfered from             */
/*                             ntrAdjustmentHeaderUpdate                    */
/*                             - (SOS#25112) (YokeBeen03)                   */
/* 27-May-2005  YokeBeen       Changed the trigger point of NSC into the    */
/*                             NSCLog upon Finalized in the trigger,        */
/*                             ntrAdjustmentHeaderUpdate.                   */
/*                             - (SOS#36136) (YokeBeen04)                   */
/* 09-Aug-2005  Vicky          Add ADJLOG as Configkey for Interface        */
/*                                                                          */
/* 18-Oct-2005  Shong          Check the FinalizeFlag when generate the     */
/*                             Interface record for C4 GOLD                 */
/*                             -- (SOS#25798) (Shong01)                     */
/* 29-Nov-2005  Shong          Check the FinalizeFlag when generate the     */
/*                             Interface record for WTC TH                  */
/*                             -- (SOS#43448) (Shong02)              */
/* 15-Feb-2006  Vicky          Check the FinalizeFlag when generate the     */
/*                             Interface record for ADJLOG                  */
/* 19-Oct-2006  MaryVong       Add in RDT compatible error messages         */
/* 28-Jun-2007  MaryVong       Remove dbo.fnc_RTRIM and dbo.fnc_LTRIM       */
/* 17-Mar-2009  TLTING         Change user_name() to SUSER_SNAME()          */
/* 12-Jan-2011  AQSKC          FBR#191481 - Added new trigger point         */
/*                             for POMS interface with                      */
/*                             Configkey = "VADJLOG". - (Kc01)              */
/* 13-Jan-2012  YTWan     1.3  Adjustment Email Notification - (Wan01)      */
/* 27-Dec-2013  MCTang    1.4  Added new trigger point - ADJ2LOG for        */
/*                             Alternate. (MC01)                            */
/* 28-Sep-2016  Leong     1.5  Skip trigger if ArchiveCop = '9'.            */
/* 27-Jul-2017  TLTING    1.6  Remove SETROWCOUNT                           */
/****************************************************************************/

CREATE TRIGGER [dbo].[ntrAdjustmentHeaderAdd]
 ON  [dbo].[ADJUSTMENT]
 FOR INSERT
 AS
 BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE
   @b_Success              int            -- Populated by calls to stored procedures - was the proc successful?
   , @n_err                int            -- Error number returned by stored procedure or this trigger
   , @n_err2               int            -- For Additional Error Detection
   , @c_errmsg             NVARCHAR(250)  -- Error message returned by stored procedure or this trigger
   , @n_continue           int
   , @n_starttcnt          int            -- Holds the current transaction count
   , @c_preprocess         NVARCHAR(250)  -- preprocess
   , @c_pstprocess         NVARCHAR(250)  -- post process
   , @n_cnt                int
   , @c_Adjustmentkey      NVARCHAR(10)
   , @c_storerkey          NVARCHAR(15)
   --, @c_NIKEREGITF NVARCHAR(1) -- (YokeBeen04)
   , @c_NWITF              NVARCHAR(1)    -- Added by MaryVong on 07-Jun-2004 (IDSHK - Nuance Watson)
   , @c_WTCITF             NVARCHAR(1)    -- Added by MaryVong on 25-Jun-2004 (IDSHK - WTC)
   , @c_C4ITF              NVARCHAR(1)    -- Added By MaryVong on 17-Aug-2004 (SOS25798-C4)
   , @c_ADJITF             NVARCHAR(1)    -- Added By Vicky on 09-Aug-2005 (Generic)
   , @c_authority_vadjitf  NVARCHAR(1)    -- (Kc01)
   , @c_AdjStatusControl   NVARCHAR(30)   --(Wan01)
   , @c_FinalizedFlag      NVARCHAR(10)   --(Wan01)

 SELECT @n_continue     = 1
   , @n_starttcnt       = @@TRANCOUNT
   , @b_Success         = 0
   , @n_err             = 0
   , @n_err2            = 0
   , @c_errmsg          = ''
   , @c_preprocess      = ''
   , @c_pstprocess      = ''
   , @n_cnt             = 0
   , @c_Adjustmentkey   = ''
   , @c_storerkey       = ''
   --, @c_NIKEREGITF       = ''   -- (YokeBeen04)
   , @c_NWITF           = ''
   , @c_WTCITF          = ''
   , @c_C4ITF           = ''
   , @c_ADJITF          = ''

   SET @c_AdjStatusControl = 0   --(Wan01)
   SET @c_FinalizedFlag    = ''  --(Wan01)

   /* #INCLUDE <TRAHA1.SQL> */
   
   -- To Skip all the trigger process when Insert the history records from Archive as user request
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END

   /* IDSV5 - Leo */
   If @n_continue = 1 or @n_continue = 2
   Begin
      Declare @c_primarykey NVARCHAR(10), @c_adjtype NVARCHAR(3), @c_adjrefno NVARCHAR(10), @c_whseorigin NVARCHAR(6)
      Declare @c_facility NVARCHAR(5), @c_old_facility NVARCHAR(5), @c_old_storerkey NVARCHAR(15)
      Declare @b_check_type NVARCHAR(1), @b_check_ref NVARCHAR(1), @b_check_ref_isnum NVARCHAR(1), @b_check_whse NVARCHAR(1)
      Declare @c_authority NVARCHAR(1), @b_check_asn NVARCHAR(1)
      Select @c_primarykey = '', @c_old_facility = '', @c_old_storerkey = ''

      While 1 = 1
      Begin
         Select TOP 1 @c_primarykey = Adjustmentkey,
                @c_adjtype = Adjustmenttype,
                @c_adjrefno = customerrefno,
                @c_whseorigin = fromtowhse,
                @c_facility = Facility,
                @c_storerkey = Storerkey
           From INSERTED (NOLOCK)
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
                                null,       -- Sku
                                'ADJHDR - ADJ TYPE REQUIRED',      -- ConfigKey
                                @b_success    output,
                                @c_authority  output,
                                @n_err        output,
                                @c_errmsg     output
            If @b_success <> 1
            Begin
               SELECT @n_continue = 3, @n_err = 62776
               Select @c_errmsg = 'ntrAdjustmentHeaderAdd :' + dbo.fnc_RTrim(@c_errmsg)
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
                                null,   -- Sku
                                'ADJHDR - ADJ REF REQUIRED',      -- ConfigKey
                                @b_success    output,
                                @c_authority  output,
                                @n_err        output,
                                @c_errmsg     output
            If @b_success <> 1
            Begin
               SELECT @n_continue = 3, @n_err = 62777
               Select @c_errmsg = 'ntrAdjustmentHeaderAdd :' + dbo.fnc_RTrim(@c_errmsg)
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
               SELECT @n_continue = 3, @n_err = 62778
               Select @c_errmsg = 'ntrAdjustmentHeaderAdd :' + dbo.fnc_RTrim(@c_errmsg)
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
               SELECT @n_continue = 3, @n_err = 62779
               Select @c_errmsg = 'ntrAdjustmentHeaderAdd :' + dbo.fnc_RTrim(@c_errmsg)
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
               SELECT @n_continue = 3, @n_err = 62780
               Select @c_errmsg = 'ntrAdjustmentHeader :' + dbo.fnc_RTrim(@c_errmsg)

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

         If @b_check_type = '1' and (dbo.fnc_RTrim(@c_adjtype) is null or dbo.fnc_RTrim(@c_adjtype) = '')
         Begin
            SELECT @n_continue = 3, @n_err = 62781 --50000
            SELECT @c_errmsg = 'VALIDATION ERROR: Adjustment Type is Required.'
            Break
         End

         If @b_check_ref = '1' and (dbo.fnc_RTrim(@c_adjrefno) is null  or dbo.fnc_RTrim(@c_adjrefno) = '')
         Begin
            SELECT @n_continue = 3, @n_err = 62782 --50000
            SELECT @c_errmsg = 'VALIDATION ERROR: Adjustment Reference Number is Required.'
            Break
         End

         If @b_check_ref_isnum = '1' and isnumeric(@c_adjrefno) <> 1
         Begin
            SELECT @n_continue = 3, @n_err = 62783 --50000
            SELECT @c_errmsg = 'VALIDATION ERROR: Invalid Adjustment Reference Number. Characters Not Allowed.'
            Break
         End

         If @b_check_whse = '1' and (dbo.fnc_RTrim(@c_whseorigin) is null or dbo.fnc_RTrim(@c_whseorigin) = '') and @c_adjtype in ('TOA', 'BRA')
         Begin
            SELECT @n_continue = 3, @n_err = 62784 --50000
            SELECT @c_errmsg = 'VALIDATION ERROR: Warehouse Origin is Required.'
            Break
         End

         If @b_check_asn = '1' and @c_adjtype = '01' and
            ((dbo.fnc_RTrim(@c_adjrefno) is null or dbo.fnc_RTrim(@c_adjrefno) = '') or not exists(Select 1 from receipt (nolock) where receiptkey = @c_adjrefno))
         Begin
            SELECT @n_continue = 3, @n_err = 62785 --50000
            select @c_errmsg = 'VALIDATION ERROR: Invalid Adjustment Reference No. (ReceiptKey).'
            Break
         End
      End
   End

   --(Wan01) - START
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF Update(FinalizedFlag)
      BEGIN
         IF EXISTS ( SELECT 1 FROM INSERTED
                     JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'ADJApvmail')
                                                    AND(INSERTED.Storerkey = @c_Storerkey)
                                                    AND(INSERTED.FinalizedFlag = CL.Short))
                     --WHERE FinalizedFlag = 'S' ) -- Submitted
         BEGIN
            EXECUTE dbo.nspGetRight NULL                 -- facility
                                 ,  @c_Storerkey         -- Storerkey
                                 ,  NULL  -- Sku
                                 ,  'AdjStatusControl'   -- Configkey
                                 ,  @b_success           OUTPUT
                                 ,  @c_AdjStatusControl  OUTPUT
                                 ,  @n_err               OUTPUT
                                 ,  @c_errmsg            OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 62801
               SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                             + ': Error Getting StorerCongfig for Storer: ' + @c_Storerkey
                             + '. (ispWAVRL01)'
            END

            SELECT @c_FinalizedFlag = INSERTED.FinalizedFlag
            FROM INSERTED

            IF @c_AdjStatusControl = '1'
            BEGIN
               SELECT @c_Adjustmentkey = Adjustmentkey FROM INSERTED
               EXEC ispGenTransmitLog3 'AdjStatusControl', @c_Adjustmentkey, @c_FinalizedFlag, @c_storerkey, ''
                                    ,  @b_success OUTPUT
                                    ,  @n_err OUTPUT
                                    ,  @c_errmsg OUTPUT


               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 62802     -- should be set to the sql errmessage but i don't know how to do so.
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 TableName (AdjStatusControl) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
         END
      END
   END
   --(Wan01) - END
-- (YokeBeen04) - Start
-- -- (YokeBeen01) - Start
--  IF @n_continue = 1 OR @n_continue = 2
--  BEGIN
--   IF EXISTS (SELECT 1 FROM ADJUSTMENT, INSERTED WHERE ADJUSTMENT.Adjustmentkey = INSERTED.Adjustmentkey)
--   BEGIN
--    SELECT @c_Adjustmentkey = ''
--    SELECT @c_storerkey = INSERTED.Storerkey ,
--       @c_FinalizeFlag = INSERTED.FinalizeFlag
--            FROM INSERTED
--    SELECT @c_NIKEREGITF = '0'
--
--    EXECUTE nspGetRight
--     NULL,     -- facility
--     @c_storerkey,   -- Storerkey
--     NULL,     -- Sku
--     'NIKEREGITF',  -- Configkey
--     @b_success   OUTPUT,
--     @c_NIKEREGITF  OUTPUT,
--     @n_err    OUTPUT,
--     @c_errmsg   OUTPUT
--
--    IF @b_success <> 1
--    BEGIN
--     SELECT @n_continue = 3
--     SELECT @c_errmsg = 'ntrAdjustmentHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
--    END
--
--    IF @c_NIKEREGITF = '1'
--    BEGIN
--     SELECT @c_Adjustmentkey = INSERTED.Adjustmentkey
--       FROM INSERTED (NOLOCK)
--
-- -- (YokeBeen03) - Start
-- --             -- Added By SHONG on 12-Jul-2004
-- --             -- Only certain Reason Code require for interface
-- --             IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)
-- --                      JOIN ADJUSTMENTDETAIL ADJ (NOLOCK) ON ADJ.ReasonCode = CODELKUP.Code
-- --                      WHERE ListName = 'ADJReason'
-- --                      AND   Short = 'NSC'
-- --                      AND   ADJ.AdjustmentKey = @c_Adjustmentkey )
-- --             BEGIN
--      -- (YokeBeen02) - Start
--                EXEC ispGenNSCLog 'NIKEREGADJ', @c_Adjustmentkey, '', @c_storerkey, ''
--                , @b_success OUTPUT
--                , @n_err OUTPUT
--                , @c_errmsg OUTPUT
--
--                IF @b_success <> 1
--                BEGIN
--                   SELECT @n_continue = 3
--         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63811   -- should be set to the sql errmessage but i don't know how to do so.
--         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Unable To Obtain NSCLogKey. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
--                END
--      -- (YokeBeen02) - End
-- --             END -- Reason Code require for interface
-- -- (YokeBeen03) - End
--    END -- @c_NIKEREGITF = '1'
--        END -- IF valid record
--     END -- IF @n_continue = 1
-- -- (YokeBeen01) - End
-- (YokeBeen04) - End

   -- Added By MaryVong on 07-Jun-2004 (IDSHK - Nuance Watson)- Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED
                 WHERE FinalizedFlag = 'Y') --  SOS#43448 Do not insert into transmitlog2 when FinalizedFlag <> 'Y'
      BEGIN
         SELECT @c_Adjustmentkey = ''
         -- (SHONG02)
         SELECT @c_storerkey = INSERTED.Storerkey,
                @c_Adjustmentkey = INSERTED.Adjustmentkey,
                @c_adjtype = INSERTED.Adjustmenttype
         FROM INSERTED
         WHERE FinalizedFlag = 'Y' --  SOS#43448 Do not insert into transmitlog2 when FinalizedFlag <> 'Y'

         SELECT @c_NWITF = '0'

         EXECUTE nspGetRight
                  NULL,          -- facility
                  @c_storerkey,  -- Storerkey
                  NULL,          -- Sku
                  'NWInterface', -- Configkey
                  @b_success  OUTPUT,
                  @c_NWITF    OUTPUT,
                  @n_err      OUTPUT,
                  @c_errmsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @n_err = 62786
            SELECT @c_errmsg = 'ntrAdjustmentHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
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
                  SELECT @n_err = 62787 --63811   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (NWINVADJ01) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
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
                  SELECT @n_err = 62788 --63811   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (NWINVADJ) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
         END -- @c_NWITF = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added By MaryVong on 07-Jun-2004 (IDSHK - Nuance Watson)- End

   -- Added By MaryVong on 25-Jun-2004 (IDSHK - WTC)- Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      --  SOS#43448 Do not insert into transmitlog2 when FinalizedFlag <> 'Y'
      IF EXISTS (SELECT 1 FROM INSERTED WHERE FinalizedFlag = 'Y')
      BEGIN
         SELECT @c_Adjustmentkey = ''

         SELECT @c_storerkey = INSERTED.Storerkey,
                @c_adjtype = INSERTED.Adjustmenttype,
                @c_Adjustmentkey = INSERTED.Adjustmentkey
         FROM INSERTED (NOLOCK)
         WHERE FinalizedFlag = 'Y'

         SELECT @c_WTCITF = '0'

         EXECUTE nspGetRight
                  NULL,             -- facility
                  @c_storerkey,     -- Storerkey
                  NULL,             -- Sku
                  'WTCInterface',   -- Configkey
                  @b_success  OUTPUT,
                  @c_WTCITF   OUTPUT,
                  @n_err      OUTPUT,
                  @c_errmsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @n_err = 62789
            SELECT @c_errmsg = 'ntrAdjustmentHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
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
               SELECT @n_err = 62790 --63811   -- should be set to the sql errmessage but i don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog2 Table (WTCADJ) Failed. . (ntrAdjustmentHeaderAdd)'
            END
         END -- @c_WTCITF = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added By MaryVong on 25-Jun-2004 (IDSHK - WTC)- End

   -- Added By MaryVong on 17-Aug-2004 (SOS25798-C4)- Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM ADJUSTMENT (NOLOCK), INSERTED (NOLOCK) WHERE ADJUSTMENT.Adjustmentkey = INSERTED.Adjustmentkey
                    AND INSERTED.FinalizedFlag = 'Y') -- (SOS#25798) (Shong01)
      BEGIN
         SELECT @c_Adjustmentkey = ''
         SELECT @c_storerkey = INSERTED.Storerkey FROM INSERTED
         SELECT @c_C4ITF = '0'

         EXECUTE nspGetRight
                  NULL,          -- facility
                  @c_storerkey,  -- Storerkey
                  NULL,          -- Sku
                  'C4ITF',       -- Configkey
                  @b_success  OUTPUT,
                  @c_C4ITF    OUTPUT,
                  @n_err      OUTPUT,
                  @c_errmsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @n_err = 62791
            SELECT @c_errmsg = 'ntrAdjustmentHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_C4ITF = '1'
         BEGIN
            SELECT @c_Adjustmentkey = INSERTED.Adjustmentkey,
                   @c_adjtype = INSERTED.Adjustmenttype
            FROM INSERTED (NOLOCK)

            -- Insert a record into TransmitLog2 table
            IF @c_adjtype = '01'
            BEGIN
                EXEC ispGenTransmitLog2 'C4ADJ01', @c_Adjustmentkey, '', @c_storerkey, ''
                , @b_success OUTPUT
                , @n_err OUTPUT
                , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 62792 --63811   -- should be set to the sql errmessage but i don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog2 Table (C4ADJ01) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
            ELSE IF @c_adjtype NOT IN ('01','10')
            BEGIN
               EXEC ispGenTransmitLog2 'C4ADJ', @c_Adjustmentkey, '', @c_storerkey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 62793 --63811   -- should be set to the sql errmessage but i don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog2 Table (C4ADJ) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END
         END -- @c_C4ITF = '1'
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added By MaryVong on 17-Aug-2004 (SOS25798-C4) - End

   -- Added By Vicky on 09-Aug-2005 (Generic) - Start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (SELECT 1 FROM ADJUSTMENT (NOLOCK), INSERTED (NOLOCK) WHERE ADJUSTMENT.Adjustmentkey = INSERTED.Adjustmentkey
                       AND INSERTED.FinalizedFlag = 'Y') -- Do not insert into transmitlog3 when FinalizedFlag <> 'Y'
      BEGIN
         SELECT @c_Adjustmentkey = ''
         SELECT @c_storerkey = INSERTED.Storerkey FROM INSERTED
         SELECT @c_ADJITF = '0'

         EXECUTE nspGetRight
                  NULL,          -- facility
                  @c_storerkey,  -- Storerkey
                  NULL,          -- Sku
                  'ADJLOG',      -- Configkey
                  @b_success     OUTPUT,
                  @c_ADJITF      OUTPUT,
                  @n_err         OUTPUT,
                  @c_errmsg      OUTPUT

         IF @b_success <> 1
         BEGIN
             SELECT @n_continue = 3, @n_err = 62794
             SELECT @c_errmsg = 'ntrAdjustmentHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_ADJITF = '1'
         BEGIN
            SELECT @c_Adjustmentkey = INSERTED.Adjustmentkey
            FROM INSERTED (NOLOCK)

            -- Insert a record into TransmitLog3 table
            EXEC ispGenTransmitLog3 'ADJLOG', @c_Adjustmentkey, '', @c_storerkey, ''
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 62795 --63811   -- should be set to the sql errmessage but i don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (ADJLOG) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- @c_ADJITF = '1'

         -- (MC01) - S
         SELECT @c_ADJITF = '0'

         EXECUTE nspGetRight
            NULL,          -- facility
            @c_storerkey,  -- Storerkey
            NULL,          -- Sku
            'ADJ2LOG',     -- Configkey
            @b_success     OUTPUT,
            @c_ADJITF      OUTPUT,
            @n_err         OUTPUT,
            @c_errmsg      OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @n_err = 62794
            SELECT @c_errmsg = 'ntrAdjustmentHeaderAdd' + dbo.fnc_RTrim(@c_errmsg)
         END

         IF @c_ADJITF = '1'
         BEGIN
            SELECT @c_Adjustmentkey = INSERTED.Adjustmentkey
            FROM INSERTED (NOLOCK)

            -- Insert a record into TransmitLog3 table
            EXEC ispGenTransmitLog3 'ADJ2LOG', @c_Adjustmentkey, '', @c_storerkey, ''
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 62795 --63811   -- should be set to the sql errmessage but i don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err) + ': Insert Into TransmitLog3 Table (ADJ2LOG) Failed. (ntrAdjustmentHeaderAdd)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END -- @c_ADJITF = '1'
         -- (MC01) - E

         -- (KC01) - Start
         SELECT @c_Adjustmentkey = INSERTED.Adjustmentkey
         FROM INSERTED (NOLOCK)
         SELECT @b_success = 0
         EXECUTE dbo.nspGetRight  '',   -- Facility
                  @c_StorerKey,         -- Storer
                  '',                   -- Sku
                  'VADJLOG',            -- ConfigKey
                  @b_success               OUTPUT,
                  @c_authority_vadjitf     OUTPUT,
                  @n_err                   OUTPUT,
                  @c_errmsg                OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63813
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                             + ': Retrieve of Right (VADJLOG) Failed (ntrAdjustmentHeaderAdd) ( SQLSvr MESSAGE='
                             + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
         ELSE
         BEGIN
            IF @c_authority_vadjitf = '1'
            BEGIN
               EXEC dbo.ispGenVitalLog  'VADJLOG', @c_Adjustmentkey, '', @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- @c_authority_vadjitf = '1'
         END -- IF @b_success = 1
         -- (KC01) - End
      END -- IF valid record
   END -- IF @n_continue = 1
   -- Added By Vicky on 09-Aug-2005 (Generic) - End

   IF @n_continue=1 or @n_continue=2
   BEGIN
      UPDATE ADJUSTMENT SET TrafficCop = NULL, AddDate = GETDATE(), AddWho=SUSER_SNAME(), EditDate = GETDATE(), EditWho=SUSER_SNAME() FROM ADJUSTMENT,inserted
      WHERE ADJUSTMENT.AdjustmentKey=inserted.AdjustmentKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62796 --66700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ADJUSTMENT. (nspAdjustmentHeaderAdd)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   /* #INCLUDE <TRAHA2.SQL> */
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrAdjustmentHeaderAdd'
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