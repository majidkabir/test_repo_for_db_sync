SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/  
/* Trigger: ntrItrnAdd                                                         */  
/* Creation Date:                                                              */  
/* Copyright: Maersk                                                           */  
/* Written by:                                                                 */  
/*                                                                             */  
/* Purpose:                                                                    */  
/*                                                                             */  
/* Usage:                                                                      */  
/*                                                                             */  
/* Called By: When records added into ITRN                                     */  
/*                                                                             */  
/* PVCS Version: 1.9                                                           */  
/*                                                                             */  
/* Version: 5.4                                                                */  
/*                                                                             */  
/* Data Modifications:                                                         */  
/*                                                                             */  
/* Updates:                                                                    */  
/* Date         Author       Ver.   Purposes                                   */  
/* 09-Dec-2002  YokeBeen     1.0    - (SOS#/FBR8719) - (YokeBeen01)            */  
/* 17-Oct-2003  YokeBeen     1.0    NIKE Regional (NSC) Project (SOS#15352)    */  
/*                                  - (YokeBeen02).                            */  
/* 01-Nov-2004  By Local IT  1.0    Nuance outbound interface modification     */  
/*                                  - (SOS#27626).                             */  
/* 28-Dec-2004  YokeBeen     1.0    For NSC 947-InvAdj - (YokeBeen03).         */  
/* 20-Dec-2004  SHONG        1.0    Singapore Maxxium Interface modification   */  
/*                                  - (SOS#30123).                             */  
/* 17-May-2005  MaryVong     1.0    - (SOS#30123).                             */  
/* 08-Jul-2005  June         1.0    SOS37864 - get Invrptlogkey when insert    */  
/*                                  to Invrptlog. Old script used trxlogkey.   */  
/* 19-Jul-2005  June         1.0    SOS36699 - check for validity of IQC       */  
/*                                  Tradereturnkey before assign status '7'    */  
/* 06-FEB-2006  ONG01        1.0    SOS45848 - Remove checking of ID.Status    */  
/*                                  for interface 'TBLREGMV'                   */  
/* 28-Apr-2006  Vicky        1.0    SOS#49377 - Add Configkey 'INVMOVELOG'     */  
/* 10-May-2006  MaryVong     1.0    Add in RDT compatible error messages       */  
/* 07-Sep-2006  MaryVong     1.0    Add in RDT compatible error messages       */  
/* 27-Oct-2006  Vicky        1.0    SOS#61049 - To include Movement between    */  
/*                                  same HostWHCode but with Locationflag      */  
/*                                  changes - Configkey = INVMOVELOG-LOCFLAG   */  
/* 14-Mar-2007  Vicky        1.0    When INVMOVELOG-LOCFLAG is turned on,      */  
/*                                  only insert into Transmitlog3 when         */  
/*                                  FromWHCode = ToWHCode                      */  
/* 22-Feb-2007  June         1.0    SOS68834 - NZMM Inventory Transfer         */  
/* 28-May-2007  YokeBeen     1.0    SOS#74893 - Trigger records from UCC Move  */  
/*                                  into TransmitLog (WMS-E1) Interface.       */  
/*                                  Changed for SQL2005 compatibility.         */  
/*                                  - (YokeBeen04).                            */  
/* 09-May-2007  MC           1.0    WSOS#75233 - Add Configkey 'HWCDMVLOG'     */  
/* 31-Dec-2007  SHONG        1.0    SOS#89405 - Only Interface to OW if        */  
/*                                  InvantoryQC.Reason = Codelkup.Code and     */  
/*                                  Codelkup.Long = 'OW'.                      */  
/* 24-Mar-2009  SHONG        1.0    Performance Tuning                         */  
/* 07-May-2009  Leong        1.1    SOS# 135041, 134750 - Extend field size &  */  
/*                                  Incorrect Storer ConfigKey                 */  
/* 10-Sep-2009  TLTING       1.2    SOS146709 Set Trigantic intf mandatory     */  
/*                                  (tlting01)                                 */  
/* 22-Mar-2010  YokeBeen     1.3    SOS#165608 - Trigger records when move     */  
/*                                  between HostWhCode for OWITF Storer with   */  
/*                                  Tablename = "OWHWCDMV". - (YokeBeen05)     */  
/* 12-Jul-2010  Leong        1.4    SOS# 181213 - Bug fix on BEGIN / END       */  
/* 15-Oct-2010  YokeBeen     1.5    SOS#192382 - Added verification on trigger */  
/*                                  point of "OWHWCDMV". Records must not      */  
/*                                  trigger if already have record "OWINVQC".  */  
/*                                  - (YokeBeen06)                             */  
/* 22-Dec-2010  YokeBeen     1.6    SOS#198768 - Blocked interface on process  */  
/*                                  of re-allocation with Configkey = 'GDSITF' */  
/*                                  - (YokeBeen07)                             */  
/* 25-Jan-2011  James        1.7    SOS#203398 - Allow SUSPENDED SKU to insert */  
/*                                  ITRN if TranType <> 'MV' (james01)         */  
/* 14-Jun-2011  ChewKP       1.8    SOS#217781,217782 - Insert AJ, WD Record to*/  
/*                                  BONSKU When InsertBONDSKU = 1 (ChewKP01)   */  
/* 03-Jan-2012  Leong        1.9    SOS#233138 - Reset Variable for INVMOVELOG */ 
/* 20-Dec-2012  TKLIM        1.10   SOS#264529 - Add SKUGroup to BONSKU (TK001)*/
/* 09-Apr-2013  Shong        2.0    Replace GetKey with isp_GetTriganticKey    */
/*                                  to reduce blocking                         */ 
/* 22-May-2013  TLTING02     2.1    Call nspg_getkey to gen TriganticKey       */
/* *************************************************************************** */
/*                                  Base on PVCS SQL2005_Unicode version 1.2.  */
/* 02-Aug-2013  GTGOH        1.3    SOS#291603 -Remark trigger for RCPTMSF     */
/*                                  (GOH01)                                    */
/* 18-Sep-2014  TLTING       1.4    Doc Status Tracking Log TLTING03           */
/* 24-Apr-2014  CSCHONG      2.2    Add Lottable06-15 (CS01)                   */
/* 11-May-2015  TLTING       2.3    Disable Trigantics                         */
/* 12-Feb-2014  YTWan        2.4    SOS#315474 - Project Merlion ?Exceed GTM   */
/*                                  Kiosk Module; ConfirmPick Move (Wan01)     */
/* 12-Nov-2015  Leong        2.5    SOS# 356939 - Revise error message.        */
/* 03-Aug-2016  TLTING04     2.3    Filter getright data                       */
/* 21-Sep-2016  SHONG01      2.4    Remove SET ROWCOUNT                        */
/* 18-Apr-2017  KHChan       2.5    SOS#WMS-1533 - Add Move trigger for        */
/*                                  WebService (KH01)                          */
/* 13-DEC-2017  Wan02        2.6    WMS-3543-CN_DYSON_Close serialno status_CR */
/* 06-Feb-2018  SWT02        2.7    Added Channel Management Logic             */
/* 22-Mar-2018  Wan03        2.7    WMS-4288 - [CN] UA Relocation Phase II -   */
/*                                  Exceed Channel of IQC                      */
/* 28-Jan-2019  TLTING_ext   2.8    exlarge externorderkey field length        */
/* 16-Jul-2019  KHChan       2.9    WMS-9799 - Add Move trigger (WHCODE) for   */
/*                                  WebService(KH02)                           */
/* 18-Nov-2019  MCTang       2.9    Duplicate WMS-9799 for OMS (MC02)          */
/* 05-Mar-2020  MCTang       3.0    Add ISNULL for HostWhCode (MC03)           */
/* 26-Nov-2020  LZG          3.1    INC1360752 - Get ITRN.ToLoc if user        */
/*                                  leave blank ToLoc (ZG01)                   */  
/* 17-May-2022  YTKuek       3.2    Add additional move trigger for            */
/*                                  WebService interface (YT01)                */
/* 23-May-2022  LiLiChua     3.3    LFI-5880 - Add Configkey 'HWCDMV2LOG'(LL01)*/
/* 15-Mar-2024  Wan01        3.4    UWP-16968-Post PalletType to Inventory When*/
/*                                  Finalize                                   */
/*******************************************************************************/  
CREATE   TRIGGER [dbo].[ntrItrnAdd]  
ON  [dbo].[ITRN]  
FOR INSERT  
AS 
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @c_SkuDefAllowed      NVARCHAR(20)  -- Sku Default Allowed  
         , @c_itrnkey            NVARCHAR(10)  -- itrn key  
         , @c_InsertStorerKey    NVARCHAR(15)  -- StorerKey Being Inserted  
         , @c_InsertSku          NVARCHAR(20)  -- Sku Being Inserted  
         , @c_InsertLot          NVARCHAR(30)  -- Lot Being Inserted  
         , @c_InsertFromLoc      NVARCHAR(30)  -- From Location If Move  
         , @c_InsertFromID       NVARCHAR(30)  -- From ID If Move  
         , @c_InsertToLoc        NVARCHAR(30)  -- Loc Being Inserted  
         , @c_InsertToID         NVARCHAR(30)  -- ID Being Inserted  
         , @c_InsertPackKey      NVARCHAR(10)  -- Packkey being inserted  
         , @c_status             NVARCHAR(10)  -- Status / Hold Flag  
         , @n_casecnt            int       -- Casecount being inserted  
         , @n_innerpack          int       -- innerpacks being inserted  
         , @n_Qty                int       -- QTY (Most important) being inserted  
         , @n_pallet             int       -- pallet being inserted  
         , @f_cube               float     -- cube being inserted  
         , @f_grosswgt           float     -- grosswgt being inserted  
         , @f_netwgt             float     -- netwgt being inserted  
         , @f_otherunit1         float     -- other units being inserted.  
         , @f_otherunit2         float     -- other units being inserted too.  
         , @c_lottable01         NVARCHAR(18)  -- Lot lottable01  
         , @c_lottable02         NVARCHAR(18)  -- Lot lottable02  
         , @c_lottable03         NVARCHAR(18)  -- Lot lottable03  
         , @d_lottable04         datetime  -- Lot lottable04  
         , @d_lottable05         datetime  -- Lot lottable05  
         /*CS01 Start*/
         , @c_lottable06         NVARCHAR(30)  -- Lot lottable06  
         , @c_lottable07         NVARCHAR(30)  -- Lot lottable07  
         , @c_lottable08         NVARCHAR(30)  -- Lot lottable08
         , @c_lottable09         NVARCHAR(30)  -- Lot lottable09  
         , @c_lottable10         NVARCHAR(30)  -- Lot lottable10  
         , @c_lottable11         NVARCHAR(30)  -- Lot lottable11  
         , @c_lottable12         NVARCHAR(30)  -- Lot lottable12   
         , @d_lottable13         datetime  -- Lot lottable13 
         , @d_lottable14         datetime  -- Lot lottable14  
         , @d_lottable15         datetime  -- Lot lottable15 
         /*CS01 End*/
         , @c_LotDefToSku        NVARCHAR(5)   -- Blank Lot Defaults to Sku  
         , @c_trantype           NVARCHAR(18)  -- Transaction Type (DP,WD,MV,AJ)  
         , @c_sourcekey          NVARCHAR(20)  -- Source key  
         , @c_sourcetype         NVARCHAR(30)  -- Source type  
         , @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?  
         , @n_err                int       -- Error number returned by stored procedure or this trigger  
         , @n_err2               int       -- For Additional Error Detection  
         , @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
         , @n_continue           int          /* continuation flag  
                                               1=Continue  
                                               2=failed but continue processsing  
                                               3=failed do not continue processing  
                                               4=successful but skip furthur processing */  
         , @n_starttcnt          int       -- Holds the current transaction count  
         , @c_preprocess         NVARCHAR(250) -- preprocess  
         , @c_pstprocess         NVARCHAR(250) -- post process  
         , @c_xFacility          NVARCHAR(5)   -- (YokeBeen03)  
         , @c_InvRptLogkey       NVARCHAR(10)  -- SOS37864  
         , @c_Channel            NVARCHAR(20) = '' -- (SWT02)
         , @n_Channel_ID         BIGINT = 0 -- (SWT02)
         , @c_PalletType         NVARCHAR(10) = ''                                  --(Wan04)
  
   -- (YokeBeen05) - Added for split the values of @c_SourceKey  
   DECLARE @c_ITRNSourceKey NVARCHAR(10)  
         , @c_ITRNSourceKeyLineNum NVARCHAR(5)  
  
   -- Added By SHONG -- Trigantic  
   DECLARE @c_TriganticLogkey NVARCHAR(10)  

   DECLARE @c_MoveRefKey      NVARCHAR(10)   --(Wan01)
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
   /* How many rows are being added? If not equal to 1, error out with message */  
   /* End how many rows are being added check. */  
  
   /* What Type Of A Process Is This? DP=Deposit, WD=Withdrawal, MV=Move, AJ=Adjustment */  
   IF @n_continue=1 or @n_continue=2  
   BEGIN  
      SELECT @c_trantype = (SELECT trantype FROM INSERTED)  
      IF @c_trantype <> 'DP' and @c_trantype <> 'WD' and @c_trantype <> 'MV' and  
         @c_trantype <> 'AJ' and @c_trantype <> 'SU'  
      BEGIN  
         /* Invalid Transaction Type - Do Not Continue */  
         SELECT @n_continue = 3 , @n_err = 61101  
         /* ROLLBACK TRAN */  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                          ': Invalid Transaction Type. Only DP,WD,MV,AJ and SU Allowed - '+  
                          'Insert Failed On Table Itrn. (ntrItrnAdd)'  
      END  
   END  
  
   -- Added By SHONG  
   -- Date: 22 Apr 2002  
   -- To ignore the transaction if the TrafficCop = '9'  
   IF EXISTS( SELECT 1 FROM INSERTED WHERE TrafficCop = '9' )  
   BEGIN  
      SELECT @n_continue = 4  
   END  
  
   /*================== Start FBR001 ========================================*/  
   /* Author : yn                                                            */  
   /* Purpose : to disallow any inventory transaction if sku is on hold      */  
   /*========================================================================*/  
   DECLARE @c_skustatus NVARCHAR(10)  
         , @c_SkuCode      NVARCHAR(20)
         , @c_SkuStorerKey NVARCHAR(15)
         
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      -- SOS# 356939 (Start)
      SELECT @c_SkuCode = '', @c_SkuStorerKey = '', @c_SkuStatus = ''
      SELECT @c_SkuCode      = SKU.Sku
           , @c_SkuStorerKey = SKU.StorerKey
           , @c_SkuStatus    = SKU.SkuStatus
      FROM INSERTED
      JOIN SKU WITH (NOLOCK)
      ON (INSERTED.Sku = SKU.Sku AND INSERTED.StorerKey = SKU.StorerKey)
      
      -- SELECT @c_SkuStatus = (SELECT sku.skustatus from SKU WITH (NOLOCK) , INSERTED
      --                         WHERE INSERTED.sku = sku.sku
      --                           AND INSERTED.STORERKEY = SKU.STORERKEY)

      IF @c_SkuStatus = 'SUSPENDED' AND @c_TranType <> 'MV' -- (james01)
      BEGIN
         SELECT @n_continue = 3 , @n_err = 61102
         SELECT @c_errmsg='NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+
                          ': Storer=' + @c_SkuStorerKey + ', Sku=' + ISNULL(RTRIM(@c_SkuCode),'') + ' is suspended - Transaction disallowed On Table Itrn. (ntrItrnAdd)'
      END
      -- SOS# 356939 (End)
   END  
   /*========================End FBR001 ======================================*/  
  
   /* Execute Preprocess */  
   /* #INCLUDE <TRIA1.SQL> */  
   /* End Execute Preprocess */  
    DECLARE @c_transmitlogkey      NVARCHAR(10),  
            @c_transacttype         NVARCHAR(10),  
            @c_adjtype              NVARCHAR(10),  
            @c_refno                NVARCHAR(20),  
            -- Added By Ricky Yee For IDSV5 -------> Start  
            @c_Facility             NVARCHAR(5),  -- Modified by Vicky on 28-April-2006 for SOS#49377  
            @c_authority            NVARCHAR(1),  
            @c_authority_exeitf     NVARCHAR(1),  
            -- @c_authority_gdsitf     NVARCHAR(1),  -- (YokeBeen07)  
            @c_authority_owitf      NVARCHAR(1),  
            @c_authority_ilsitf     NVARCHAR(1),  
            @c_authority_pmtladj    NVARCHAR(1),  
            @c_authority_nikeregitf NVARCHAR(1),  -- (YokeBeen02)  
            @c_authority_nwitf      NVARCHAR(1),  -- Added by MaryVong on 08-Jun-2004 (IDSHK-Nuance Watson: Putaway Export)  
            @c_FrLocType            NVARCHAR(10), -- Added by MaryVong on 08-Jun-2004  
            @c_ToLocType            NVARCHAR(10), -- Added by MaryVong on 08-Jun-2004  
            @c_FrShort              NVARCHAR(10), -- SOS 26475 wally 25.aug.04  
            @c_ToShort              NVARCHAR(10), -- SOS 26475 wally 25.aug.04  
            @c_C4ITF                NVARCHAR(1),   -- Added by MaryVong on 24-Aug-2004 (SOS25798-C4)  
            @c_insertbondsku        NVARCHAR(1)    -- (ChewKP01)  
  
    DECLARE @n_FrFlag int  
          , @n_ToFlag int  
          , @c_FrIDStat NVARCHAR(10)  
          , @c_ToIDStat NVARCHAR(10)  
          , @c_authority_invmovlog NVARCHAR(1)        -- Added by Vicky on 28-April-2006 for SOS#49377  
          , @c_facilityTo NVARCHAR(5)                 -- Added by Vicky on 28-April-2006 for SOS#49377  
          , @c_authority_locflag NVARCHAR(1)          -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_FromLocationflag NVARCHAR(10)          -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_ToLocationflag NVARCHAR(10)            -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_FromStatus NVARCHAR(10)                -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_ToStatus NVARCHAR(10)                  -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_FromIDStatus NVARCHAR(10)              -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_ToIDStatus NVARCHAR(10)                -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_FromLotStatus NVARCHAR(10)             -- Added by Vicky on 27-Oct-2006 for SOS#61049  
          , @c_authority_hwcdmvlog NVARCHAR(1)        -- Added by MC on 09-May-2006 for SOS#75233  
          , @c_authority_OWHWCDMV NVARCHAR(1)         -- (YokeBeen05)
          , @c_authority_wsinvmovlog NVARCHAR(1)      --(KH01)
          , @c_FromLocationCategory NVARCHAR(10)      --(KH01)
          , @c_ToLocationCategory NVARCHAR(10)        --(KH01)
          , @c_authority_wsinvmovwhcdlog NVARCHAR(1)  --(KH02)
          , @c_authority_wsinvmovwhcdlog2 NVARCHAR(1) --(YT01)
          , @c_authority_OMSITRNLOGMOV   NVARCHAR(1)  --(MC02)
       , @c_authority_hwcdmv2log NVARCHAR(1)       --(LL01)
  
    DECLARE @c_authority_tblhkitf  NVARCHAR(1)  
    DECLARE @c_authority_utlitf    NVARCHAR(1)  
--GOH01    DECLARE @c_authority_msfitf    NVARCHAR(1)   -- For Singapore Maxxium  
    DECLARE @c_ConfigKey           NVARCHAR(30),  
          --@c_sValue              NVARCHAR(10)  
            @c_sValue              NVARCHAR(30)--SOS# 135041, 134750  
    DECLARE @c_authority_trigantic NVARCHAR(1),  
            @c_authority_invtrfitf NVARCHAR(1),  
            @c_authority_mxpitf    NVARCHAR(1),  
            @c_authority_ulvitf    NVARCHAR(1),  
            @c_authority_ulpitf    NVARCHAR(1)  
  
  
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      SELECT @c_InsertToLoc = Toloc, @c_InsertFromLoc = Fromloc,  
             @c_InsertStorerKey = Storerkey,  @c_InsertSku = sku  
        FROM INSERTED  
  
      IF @c_trantype='DP'  
      BEGIN  
         SELECT @c_facility = facility FROM LOC WITH (NOLOCK)  
          WHERE LOC = @c_InsertToLoc  
      END  
      ELSE IF @c_trantype='WD'  
      BEGIN  
         SELECT @c_facility = facility FROM LOC WITH (NOLOCK)  
          WHERE LOC = @c_InsertFromLoc  
      END  
      ELSE IF @c_trantype='MV'  
      BEGIN  
         DECLARE @c_fromwhcode NVARCHAR(10), @c_towhcode NVARCHAR(10)  
  
         SELECT @c_facility = facility FROM LOC WITH (NOLOCK)  
          WHERE LOC = @c_InsertFromLoc  
  
         SELECT @c_facilityTo = facility FROM LOC WITH (NOLOCK)  
          WHERE LOC = @c_InsertToLoc  
      END  
      ELSE IF @c_trantype='AJ'  
      BEGIN  
         SELECT @c_facility = facility FROM LOC WITH (NOLOCK)  
          WHERE LOC = @c_InsertFromLoc  
      END  
   END  
  
   -- DECLARE @t_Rights TABLE ( ConfigKey NVARCHAR(30), sValue NVARCHAR(10) )  
   DECLARE @t_Rights TABLE ( ConfigKey NVARCHAR(30), sValue NVARCHAR(30) )--SOS# 135041, 134750  
  
   DECLARE @nRC INT  
  
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      INSERT INTO @t_Rights  
      EXECUTE dbo.nspGetRightRecords  
             @c_Facility  
            ,@c_InsertStorerKey  
            ,@c_InsertSku  
            ,@b_Success OUTPUT  
            ,@n_Err OUTPUT  
            ,@c_ErrMsg OUTPUT  
   END  
  
   -- Initialization  
   -- SET @c_authority_gdsitf = ''  -- (YokeBeen07)  
   SET @c_authority_owitf  = ''  
   SET @c_authority_exeitf = ''  
   SET @c_authority_invmovlog = ''  
   SET @c_authority_hwcdmvlog = ''  
   SET @c_authority_OWHWCDMV = ''  -- (YokeBeen05)  
   SET @c_authority_locflag = ''  
   SET @c_authority_ilsitf = ''  
   SET @c_authority_pmtladj = ''  
   SET @c_authority_tblhkitf = ''  
   SET @c_authority_nikeregitf = ''  
   SET @c_authority_nwitf = ''  
   SET @c_authority_utlitf = ''  
--GOH01   SET @c_authority_msfitf = '' 
   SET @c_authority_trigantic = ''  
   SET @c_authority_invtrfitf = ''  
   SET @c_authority_mxpitf    = ''  
   SET @c_authority_ulvitf    = ''  
   SET @c_authority_ulpitf    = ''  
   SET @c_authority_trigantic = '1'       -- tlting01 
   SET @c_authority_wsinvmovlog = ''      --(KH01) 
   SET @c_authority_wsinvmovwhcdlog = ''  --(KH02) 
   SET @c_authority_wsinvmovwhcdlog2 = '' --(YT01) 
   SET @c_authority_OMSITRNLOGMOV = ''    --(MC02)
  SET @c_authority_hwcdmv2log = ''      --(LL01)
  
   DECLARE CUR_Rights CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT ConfigKey, sValue  
      FROM @t_Rights  
      Where ConfigKey in ('OWITF', 'EXEITF', 'INVMOVELOG', 'HWCDMVLOG', 'INVMOVELOG-LOCFLAG', 
                  'ILSITF', 'PMTLADJ', 'TBLHKITF', 'NIKEREGITF', 'NWInterface',
                  'UTLITF', 'INVTRFITF', 'MXPITF' ,'ULVITF' ,'ULPITF'
                  ,'InsertBONDSKU'        -- tlting04 
                  ,'WSINVMOVELOG'         --(KH01) 
                  ,'WSINVMOVEWHCDLOG'     --(KH02) 
                  ,'WSINVMOVEWHCDLOG2'    --(YT01) 
                  ,'OMSITRNLOGMOV'        --(MC02)
            ,'HWCDMV2LOG'       --(LL01)
                  )
  
   OPEN CUR_Rights  
  
   FETCH NEXT FROM CUR_Rights INTO @c_ConfigKey, @c_sValue  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      -- (YokeBeen01) - Start - Remarked on obsolete Configkey = 'GDSITF'  
      -- IF @c_ConfigKey = 'GDSITF' AND @c_sValue = '1'  
      --    SET @c_authority_gdsitf = '1'  
      -- (YokeBeen01) - End - Remarked on obsolete Configkey = 'GDSITF'  
  
      IF @c_ConfigKey = 'OWITF' AND @c_sValue = '1'  
         SET @c_authority_owitf = '1'  
  
      IF @c_ConfigKey = 'EXEITF' AND @c_sValue = '1'  
         SET @c_authority_exeitf = '1'  
  
      -- For SOS#49377  
      IF @c_ConfigKey = 'INVMOVELOG' AND @c_sValue = '1'  
         SET @c_authority_invmovlog = '1'  
  
      -- For SOS#75233  
      IF @c_ConfigKey = 'HWCDMVLOG' AND @c_sValue = '1'  
         SET @c_authority_hwcdmvlog = '1'  
  
        --(KH01)
      IF @c_ConfigKey = 'WSINVMOVELOG' AND @c_sValue = '1'  
         SET @c_authority_wsinvmovlog = '1'  

      --(KH02)
      IF @c_ConfigKey = 'WSINVMOVEWHCDLOG' AND @c_sValue = '1'  
         SET @c_authority_wsinvmovwhcdlog = '1' 

      --(YT01)
      IF @c_ConfigKey = 'WSINVMOVEWHCDLOG2' AND @c_sValue = '1'  
         SET @c_authority_wsinvmovwhcdlog2 = '1' 
      --(MC02)
      IF @c_ConfigKey = 'OMSITRNLOGMOV' AND @c_sValue = '1'  
         SET @c_authority_OMSITRNLOGMOV = '1' 

      --(LL01) 
      IF @c_ConfigKey = 'HWCDMV2LOG' AND @c_sValue = '1'  
         SET @c_authority_hwcdmv2log = '1'  
      
      -- For SOS#61049  
      -- IF @c_ConfigKey = 'INVMOVELOG-LOCFLA' AND @c_sValue = '1'  
      IF @c_ConfigKey = 'INVMOVELOG-LOCFLAG' AND @c_sValue = '1' -- SOS# 135041, 134750  
         SET @c_authority_locflag = '1'  
  
      IF @c_ConfigKey = 'ILSITF' AND @c_sValue = '1'  
         SET @c_authority_ilsitf = '1'  
  
      -- PMTL ADJ Export Interface  
      IF @c_ConfigKey = 'PMTLADJ' AND @c_sValue = '1'  
         SET @c_authority_pmtladj = '1'  
  
      -- TBL HK - Outbound PIX  
      IF @c_ConfigKey = 'TBLHKITF' AND @c_sValue = '1'  
         SET @c_authority_tblhkitf = '1'  
  
      IF @c_ConfigKey = 'NIKEREGITF' AND @c_sValue = '1'  
         SET @c_authority_nikeregitf = '1'  
  
      IF @c_ConfigKey = 'NWInterface' AND @c_sValue = '1'  
         SET @c_authority_nwitf = '1'  
  
      IF @c_ConfigKey = 'UTLITF' AND @c_sValue = '1'  
         SET @c_authority_utlitf = '1'  

--GOH01 Start  
--      -- For Singapore Maxxium  
--      IF @c_ConfigKey = 'MSFITF' AND @c_sValue = '1'  
--         SET @c_authority_msfitf = '1'  
--GOH01 End
  
      --  IF @c_ConfigKey = 'TRIGANTIC' AND @c_sValue = '1'    -- tlting01  
    --     SET @c_authority_trigantic = '1'  
  
      IF @c_ConfigKey = 'INVTRFITF' AND @c_sValue = '1'  
         SET @c_authority_invtrfitf = '1'  
  
      IF @c_ConfigKey = 'MXPITF' AND @c_sValue = '1'  
         SET @c_authority_mxpitf = '1'  
  
      IF @c_ConfigKey = 'ULVITF' AND @c_sValue = '1'  
         SET @c_authority_ulvitf = '1'  
  
      IF @c_ConfigKey = 'ULPITF' AND @c_sValue = '1'  
         SET @c_authority_ulpitf = '1'  
  
      IF @c_ConfigKey = 'InsertBONDSKU' AND @c_sValue = '1' -- (ChewKP01)  
         SET @c_insertbondsku = '1'  
  
      FETCH NEXT FROM CUR_Rights INTO @c_ConfigKey, @c_sValue  
   END  
   CLOSE CUR_Rights  
   DEALLOCATE CUR_Rights  
  
   /* Main Processing Starts */  
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      SELECT @b_success = 1  
      ,      @n_err     = 0  
      ,      @c_errmsg  = ''  
  
      /* Deposit Stuff */  
      IF @c_trantype='DP'  
      BEGIN  
         SELECT @c_InsertStorerKey  = itrn.StorerKey  
            ,   @c_itrnkey          = itrn.itrnkey  
            ,   @c_InsertSku        = itrn.Sku  
            ,   @c_InsertLot        = itrn.Lot  
            ,   @c_InsertToLoc      = itrn.ToLoc  
            ,   @c_InsertToID  = itrn.ToID  
            ,   @c_InsertPackkey    = itrn.Packkey  
            ,   @n_casecnt          = itrn.casecnt  
            ,   @n_innerpack        = itrn.innerpack  
            ,   @n_Qty              = itrn.qty  
            ,   @n_pallet           = itrn.pallet  
            ,   @f_cube             = itrn.cube  
            ,   @f_grosswgt         = itrn.grosswgt  
            ,   @f_netwgt           = itrn.netwgt  
            ,   @f_otherunit1       = itrn.otherunit1  
            ,   @f_otherunit2       = itrn.otherunit2  
            ,   @c_status           = itrn.status  
            ,   @c_lottable01       = itrn.lottable01  
            ,   @c_lottable02       = itrn.lottable02  
            ,   @c_lottable03       = itrn.lottable03  
            ,   @d_lottable04       = itrn.lottable04  
            ,   @d_lottable05       = itrn.lottable05  
            ,   @c_lottable06       = itrn.lottable06        --(CS01)
            ,   @c_lottable07       = itrn.lottable07        --(CS01)
            ,   @c_lottable08       = itrn.lottable08        --(CS01)
            ,   @c_lottable09       = itrn.lottable09        --(CS01)
            ,   @c_lottable10       = itrn.lottable10        --(CS01)
            ,   @c_lottable11       = itrn.lottable11        --(CS01)
            ,   @c_lottable12       = itrn.lottable12        --(CS01)
            ,   @d_lottable13       = itrn.lottable13        --(CS01)
            ,   @d_lottable14       = itrn.lottable14        --(CS01)
            ,   @d_lottable15       = itrn.lottable15        --(CS01)
            ,   @c_sourcekey        = itrn.sourcekey  
            ,   @c_sourcetype       = itrn.sourcetype  
            ,   @c_Channel          = itrn.Channel           --(SWT02)
            ,   @n_Channel_ID       = itrn.Channel_ID        --(SWT02) 
            ,   @c_PalletType       = itrn.PalletType                               --(Wan04)
           FROM ITRN WITH (NOLOCK)  
           JOIN INSERTED ON ( itrn.itrnkey = inserted.itrnkey ) 
  
         EXECUTE nspItrnAddDepositCheck  
                 @c_itrnkey      = @c_itrnkey  
            ,    @c_StorerKey    = @c_InsertStorerKey  
            ,    @c_Sku          = @c_InsertSku  
            ,    @c_Lot          = @c_InsertLot  
            ,    @c_ToLoc        = @c_InsertToLoc  
            ,    @c_ToID         = @c_InsertToID  
            ,    @c_packkey      = @c_InsertPackKey  
            ,    @c_Status       = @c_status  
            ,    @n_casecnt      = @n_casecnt  
            ,    @n_innerpack    = @n_innerpack  
            ,    @n_Qty          = @n_Qty  
            ,    @n_pallet       = @n_pallet  
            ,    @f_cube         = @f_cube  
            ,    @f_grosswgt     = @f_grosswgt  
            ,    @f_netwgt       = @f_netwgt  
            ,    @f_otherunit1   = @f_otherunit1  
            ,    @f_otherunit2   = @f_otherunit2  
            ,    @c_lottable01   = @c_lottable01  
            ,    @c_lottable02   = @c_lottable02  
            ,    @c_lottable03   = @c_lottable03  
            ,    @d_lottable04   = @d_lottable04  
            ,    @d_lottable05   = @d_lottable05 
            ,    @c_lottable06   = @c_lottable06       --(CS01)
            ,    @c_lottable07   = @c_lottable07       --(CS01)
            ,    @c_lottable08   = @c_lottable08       --(CS01) 
            ,    @c_lottable09   = @c_lottable09       --(CS01)
            ,    @c_lottable10   = @c_lottable10       --(CS01)
            ,    @c_lottable11   = @c_lottable11       --(CS01)
            ,    @c_lottable12   = @c_lottable12       --(CS01)   
            ,    @d_lottable13   = @d_lottable13       --(CS01)
            ,    @d_lottable14   = @d_lottable14       --(CS01)
            ,    @d_lottable15   = @d_lottable15       --(CS01)
            ,    @c_SourceKey    = @c_sourcekey  
            ,    @c_SourceType   = @c_sourcetype
            ,    @c_Channel      = @c_Channel           --(SWT02)
            ,    @n_Channel_ID   = @n_Channel_ID      OUTPUT --(SWT02)
            ,    @c_PalletType   = @c_PalletType                                    --(Wan04)
            ,    @b_Success      = @b_success         OUTPUT  
            ,    @n_err          = @n_err             OUTPUT  
            ,    @c_errmsg       = @c_errmsg          OUTPUT  
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
         END  
         ELSE -- Customize for HK, Modify by SHONG 21th Nov 2001  
         BEGIN  
            -- Customize for HK Phase II, One World <> EXceed Interface  
            -- Begin  
            -- Move this process to Receipt Header Update trigger.  
            --                   IF @c_sourcetype like 'ntrReceiptDetail%'  
            --                   BEGIN  
            --                   END -- @c_sourcetype like 'ntrReceiptDetail%'  
  
            /* Modification - to add records in transmitlog */  
            -- Author : Shong Wan Toh  
            -- Purpose: One World Interface  
            -- Date   : 23th Dec 2001  
            IF @c_sourcetype like 'ntrReceiptDetail%'  
            BEGIN  
               -- Get Storer Configuration -- One World Interface  
               -- Is One World Interface Turn On?  
  
               IF @c_authority_owitf = '1'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
  
                  IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK)  
                              WHERE Receiptkey = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                                AND RecType IN ('NORMAL', 'FullImRtn', 'PartImRtn', 'Exchange', 'Return', 'JX', 'OJ'))  
                  BEGIN  
                     SET @c_ITRNSourceKey = SUBSTRING(@c_SourceKey, 1, 10)  
                     SET @c_ITRNSourceKeyLineNum = SUBSTRING(@c_SourceKey, 11, 5)  
  
                     EXEC ispGenTransmitLog 'OWRCPT', @c_ITRNSourceKey, @c_ITRNSourceKeyLineNum, '', ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61103  
                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                         ': Insert Into TransmitLog Table (OWRCPT) Failed (ntrItrnAdd)' +  
                                         ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                     END  
                  END -- Valid RecType  
               END -- if one world interface is on  
               ELSE IF @c_authority_exeitf = '1'  
               BEGIN  
                  IF ( @n_continue = 1 OR @n_continue = 2 )  
                  BEGIN  
                     IF NOT EXISTS (SELECT 1 FROM TransmitLog (NOLOCK) WHERE TableName = 'RECEIPT'  
                                    AND Key1 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                                    AND Key2 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 11, 5))  
                     BEGIN  
                        EXECUTE nspg_getkey  
                               'TransmitlogKey'  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61104  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
  
                        IF @n_continue = 1 OR @n_continue = 2  
                        BEGIN  
                           INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3)  
                           VALUES ( @c_transmitlogkey, 'RECEIPT', SUBSTRING(@c_sourcekey,1, 10),  
                                    SUBSTRING(@c_sourcekey,11,5), @c_itrnkey )  
  
                           SELECT @n_err= @@Error  
                           IF NOT @n_err=0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61105  
                              SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                                ':Insert Into Table TransmitLog Table (RECEIPT) Failed. (ntrItrnAdd)'+  
                                                '(SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                           END  
  
                           -- V5 (TH) Start  
                           -- Start : SOS37864  
                           SELECT @b_success = 1  
  
                           EXECUTE nspg_getkey  
                                  'InvRptLogkey'  
                                 , 10  
                                 , @c_InvRptLogkey OUTPUT  
                                 , @b_success   OUTPUT  
                                 , @n_err       OUTPUT  
                                 , @c_errmsg    OUTPUT  
  
                           IF NOT @b_success = 1  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61106  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                               ': Unable to Obtain InvRptLogkey. (ntrItrnAdd) ( ' +  
                                               ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                           ELSE  
                           BEGIN  
                              -- End : SOS37864  
                              /* Added by MMLee for the report : Invrpt (to handle messagecode = 02 and 03 ) */  
                              /* 22 August 2001 */  
                              /* Start */  
                              INSERT InvRptLog (InvRptLogkey,tablename,key1,key2, key3)  
                              -- Start : SOS37864  
                              -- VALUES (@c_transmitlogkey, 'RECEIPT',SUBSTRING(@c_sourcekey,1, 10), SUBSTRING(@c_sourcekey,11,5), @c_itrnkey )  
                              VALUES (@c_InvRptLogkey, 'RECEIPT',SUBSTRING(@c_sourcekey,1, 10),  
                                      SUBSTRING(@c_sourcekey,11,5), @c_itrnkey )  
                              -- End : SOS37864  
  
                              SELECT @n_err= @@Error  
                              IF NOT @n_err=0  
                              BEGIN  
                                 SELECT @n_continue = 3  
                                 /* Trap SQL Server Error */  
                                 SELECT @c_errmsg= CONVERT(char(250), @n_err), @n_err = 61107  
                                 SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                                   ': Insert Failed On Table InvRptLog. (ntrItrnAdd)'+'('+  
                                                   'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                                 /* End Trap SQL Server Error */  
                              END  
                           END -- SOS37864  
                        END -- End @n_continue  
                     END -- Not Exist in Transmitlog  
                  END -- IF ( @n_continue = 1 OR @n_continue = 2 )  
               END -- IF @c_authority_exeitf = '1'  
  
               -- Added By SHONG  
               -- For Trigantic PRoject  
               IF @c_authority_trigantic = '1'  
               BEGIN  
                  SELECT @c_TriganticLogkey=''  
                  SELECT @b_success=1  
  
                  --TLTING03
                  IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) WHERE TableName = 'STSRECEIPT'  
                                 AND DocumentNo = SUBSTRING(RTRIM(@c_SourceKey), 1, 10))  
                  BEGIN  
                     SET @c_ITRNSourceKey = SUBSTRING(RTRIM(@c_SourceKey), 1, 10)
                     
                     EXEC ispGenDocStatusLog 'STSRECEIPT', @c_InsertStorerKey, @c_ITRNSourceKey, '', '','0'
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
               
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=61139   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        
                        SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                    ': Insert Failed On Table DocStatusTrack(STSRECEIPT). (ntrItrnAdd)'+'('+  
                                    'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'                                
                     END 
                  END -- not exists  
                  
                                      
--                  IF NOT EXISTS (SELECT 1 FROM TRIGANTICLOG WITH (NOLOCK) WHERE TableName = 'RECEIPT'  
--                                 AND Key1 = SUBSTRING(RTRIM(@c_SourceKey), 1, 10))  
--                  BEGIN  
--                    -- TLTING02   
--                     EXECUTE nspg_getkey  
--                            'TRIGANTICKEY'  
--                           , 10  
--                           , @c_TriganticLogkey OUTPUT  
--                           , @b_success OUTPUT  
--                           , @n_err OUTPUT  
--                           , @c_errmsg OUTPUT  
--                     IF NOT @b_success=1  
--                     BEGIN  
--                        SELECT @n_continue = 3  
--                        SELECT @n_err = 61108  
--                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
--                     END  
  
--                     IF ( @n_continue = 1 OR @n_continue = 2 )  
--                     BEGIN  
--                        INSERT TriganticLog (TriganticLogkey,tablename,key1,key2, key3)  
--                        VALUES (@c_TriganticLogkey, 'RECEIPT', SUBSTRING(@c_SourceKey, 1, 10), '', '' )  
  
--                        SELECT @n_err= @@error  
--                        IF NOT @n_err=0  
--                        BEGIN  
--                           SELECT @n_continue = 3  
--                           SELECT @n_err = 61109  
--                           SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
--                                             ': Insert Failed On Table TriganticLog. (ntrItrnAdd)'+'('+  
--                                             'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
--                        END  
--                     END --  ( @n_continue = 1 or @n_continue = 2 )  
--                  END -- not exists  
--                  ELSE  
--                  BEGIN  
--                     UPDATE TriganticLog  
--                        SET TransmitFlag = '0'  
--                      WHERE TableName = 'RECEIPT'  
--  AND TransmitFlag = '9'  
--                        AND Key1 = SUBSTRING(@c_SourceKey, 1, 10)  
 
--                     SELECT @n_err= @@error  
--                     IF NOT @n_err = 0  
--                     BEGIN  
--                        SELECT @n_continue = 3  
--                        SELECT @n_err = 61110  
--                        SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
--                                          ': Update Failed On Table TriganticLog. (ntrItrnAdd)'+'('+  
--                                          'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
--                     END  
--                  END  
               END -- if trigantic interface is on  
  
               -- Added by SHONG UTL Project  
               IF @c_authority_utlitf = '1'  
               BEGIN  
                  DECLARE @c_Devision NVARCHAR(10),  
                          @c_RcptKey  NVARCHAR(10),  
                          @c_RcptType NVARCHAR(10)  
  
                  SELECT @c_RcptKey = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                  SELECT @c_RcptType = ''  
  
                  SELECT @c_RcptType = RECEIPT.RecType FROM Codelkup WITH (NOLOCK) 
                         JOIN RECEIPT WITH (NOLOCK) ON ( CODELKUP.ListName = 'RECTYPE'  
                                                    AND CODELKUP.Code = RECEIPT.RecType )  
                  WHERE RECEIPT.ReceiptKey = @c_RcptKey  
                  AND   CODELKUP.Long = '1'  
  
                  IF ISNULL(RTRIM(@c_RcptType),'') <> ''  
                  BEGIN  
                     IF NOT EXISTS(SELECT 1 FROM Transmitlog2 WITH (NOLOCK)  
                                    WHERE TableName IN ('FACTASN', 'NFACTASN') AND Key1 = @c_RcptKey )  
                     BEGIN  
                        SELECT @c_Devision = SUSR3  
                        FROM   RECEIPTDETAIL WITH (NOLOCK)  
                        JOIN   SKU WITH (NOLOCK) ON (RECEIPTDETAIL.StorerKey = SKU.StorerKey AND  
                                                     RECEIPTDETAIL.SKU = SKU.SKU)  
                        WHERE  ReceiptKey = @c_RcptKey  
                        AND    ReceiptLineNumber = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 11, 5)  
  
                        IF @c_RcptType = 'UTLFACT'  
                        BEGIN  
                           EXEC ispGenTransmitLog2 'FACTASN', @c_RcptKey, @c_Devision, '', ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                           IF @b_success <> 1  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61111  
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                               ': Insert Into TransmitLog2 Table (FACTASN) Failed (ntrItrnAdd)' +  
                                               ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                        END -- IF @c_RcptType = 'UTLFACT'  
                        ELSE IF @c_RcptType = 'UTL3PL' OR @c_RcptType = 'UTLIMP'  
                        BEGIN  
                           EXEC ispGenTransmitLog2 'NFACTASN', @c_RcptKey, @c_Devision, '', ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                           IF @b_success <> 1  
                           BEGIN  
                             SELECT @n_continue = 3  
                   SELECT @n_err = 61112  
                             SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                              ': Insert Into TransmitLog2 Table (NFACTASN) Failed (ntrItrnAdd)' +  
                                              ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                        END -- IF @c_RcptType = 'UTL3PL' OR @c_RcptType = 'UTLIMP'  
                     END -- record not exists in Transmitlog2  
                  END -- IF ISNULL(RTRIM(@c_RcptType),'') <> ''  
               END -- IF @c_authority_utlitf = '1'  
  
            END -- if source type = Receipt Detail  
  
            -- Start : SOS68834  
            IF @c_sourcetype LIKE 'ntrTransferDetail%'  
            BEGIN  
               IF @c_authority_invtrfitf = '1'  
               BEGIN  
                  SELECT @c_InsertLot = ITRN.Lot  
                  FROM  ITRN WITH (NOLOCK)  
                  JOIN  INSERTED ON ( itrn.itrnkey = inserted.itrnkey )  
  
                  IF @c_Lottable03 = 'HOLD'  
                  BEGIN  
                     EXEC nspInventoryHoldResultSet  
                           @c_Insertlot  
  
                           , ''  
                           , ''  
                           , '' -- Storerkey  
                           , '' -- SKU  
                           , ''  
                           , ''  
                           , ''  
                           , NULL  
  
                           , NULL  
                           , @c_Lottable03 -- @c_Status  
                           , '1' -- @c_Hold  
                           , @b_Success  
                           , @n_err  
                           , @c_errmsg  
                  END  
  
                  IF NOT @b_success=1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61114  
                     SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                  END  
               END -- IF @c_authority_invtrfitf = '1'  
            END -- SourceType like 'ntrTransferDetail%'  
            -- End : SOS68834  
  
            -- SOS 20323: MXP Kitting confirmation  
            -- start: 20323  
            IF @c_sourcetype LIKE 'ntrKitDetail%'  
            BEGIN  
               IF @c_authority_mxpitf = '1'  
               BEGIN  
                  SET @c_ITRNSourceKey = SUBSTRING(@c_SourceKey, 1, 10)  
                  SET @c_ITRNSourceKeyLineNum = SUBSTRING(@c_SourceKey, 11, 5)  
  
                  EXEC ispGenTransmitLog2 'MXPKIT', @c_ITRNSourceKey, @c_ITRNSourceKeyLineNum, 'T', '0'  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
  
                  IF @b_success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61115  
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                      ': Insert Into TransmitLog Table (MXPKIT) Failed (ntrItrnAdd)' +  
                                      ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                  END  
               END -- IF @c_authority_mxpitf = '1'  
            END -- IF @c_sourcetype LIKE 'ntrKitDetail%'  
            -- end : 20323  
  
            /* Modification - to add records in transmitlog */  
            -- Author : Shong Wan Toh  
            -- Purpose: One World Interface  
            -- Date   : 15th Dec 2001  
            IF @c_sourcetype LIKE 'ntrKitDetail%'  
            BEGIN  
               -- Get Storer Configuration -- One World Interface  
               -- Is One World Interface Turn On?  
               IF @c_authority_owitf = '1'  
               BEGIN  
                  SET @c_ITRNSourceKey = SUBSTRING(@c_SourceKey, 1, 10)  
                  SET @c_ITRNSourceKeyLineNum = SUBSTRING(@c_SourceKey, 11, 5)  
  
                  EXEC dbo.ispGenTransmitLog 'OWKIT', @c_ITRNSourceKey, @c_ITRNSourceKeyLineNum, 'T', ''  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
  
                  IF @b_success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61116  
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                      + ':Insert failed on TransmitLog. (ntrItrnAdd) (SQLSvr MESSAGE='  
                                      + LTRIM(RTRIM(@c_errmsg)) + ')'  
                  END  
               END -- if one world interface is on  
  
               /* Modification - to add records in transmitlog */  
               -- Author : June  
               -- Purpose: ULP/CMC Interface  
               -- Date   : 2.Sep.2002  
  
               IF @c_authority_ulpitf = '1'  
               BEGIN  
                  SET @c_ITRNSourceKey = SUBSTRING(@c_SourceKey, 1, 10)  
                  SET @c_ITRNSourceKeyLineNum = SUBSTRING(@c_SourceKey, 11, 5)  
  
                  EXEC dbo.ispGenTransmitLog 'ULPKIT', @c_ITRNSourceKey, @c_ITRNSourceKeyLineNum, '', ''  
               , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
  
                  IF @b_success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61117  
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                      + ':Insert failed on TransmitLog (ULPKIT). (ntrItrnAdd) (SQLSvr MESSAGE='  
                                      + LTRIM(RTRIM(@c_errmsg)) + ')'  
                  END  
               END -- if exists configkey ULPITF  
            END -- if source type = kitting  
  
            -- Added By SHONG  
            -- Date: 07th Dec 2002  
            -- For Trigantic Project -- Cycle Count Extract  
            -- Begin  
            IF @c_sourcetype LIKE 'CC Deposit (%'  
            BEGIN  
               -- Get Storer Configuration -- Trigantic Interface  
               -- Is Trigantic Interface Turn On?  
               IF @c_authority_trigantic = '1'  
               BEGIN  
                  SELECT @c_TriganticLogkey=''  
                  SELECT @b_success=1  
                    
                  --TLTING03
                  IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) WHERE TableName = 'STSCCOUNT'  
                                 AND DocumentNo = SUBSTRING(ISNULL(RTRIM(@c_SourceType),''), 13, 10))  
                  BEGIN  
                     SET @c_ITRNSourceKey = SUBSTRING(ISNULL(RTRIM(@c_SourceType),''), 13, 10)
                     
                     EXEC ispGenDocStatusLog 'STSCCOUNT', @c_InsertStorerKey, @c_ITRNSourceKey, '', '','0'
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
               
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=61139   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        
                        SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                    ': Insert Failed On Table DocStatusTrack (STSCCOUNT). (ntrItrnAdd)'+'('+  
                                    'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'                                
                     END 
                  END -- not exists  
                  
                                    
--                  IF NOT EXISTS (SELECT 1 FROM TriganticLog WITH (NOLOCK) WHERE TableName = 'CCOUNT'  
--            AND    Key1 = SUBSTRING(ISNULL(RTRIM(@c_SourceType),''), 13, 10))  
--                  BEGIN  
--                     EXECUTE nspg_getkey  
--                            'TRIGANTICKEY'  
--                           , 10  
--                           , @c_TriganticLogkey OUTPUT  
--                           , @b_success OUTPUT  
--                           , @n_err OUTPUT  
--                           , @c_errmsg OUTPUT  
--                     IF NOT @b_success=1  
--                     BEGIN  
--                        SELECT @n_continue = 3  
--                        SELECT @n_err = 61118  
--                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
--                     END  
  
--                     IF ( @n_continue = 1 or @n_continue = 2 )  
--                     BEGIN  
--                        INSERT TriganticLog (TriganticLogkey,tablename,key1,key2, key3)  
--                        VALUES (@c_TriganticLogkey, 'CCOUNT',  
--                                SUBSTRING(ISNULL(RTRIM(@c_SourceType),''), 13, 10), '', '' )  
  
--                        SELECT @n_err= @@Error  
--                        IF NOT @n_err=0  
--                        BEGIN  
--                           SELECT @n_continue = 3  
--                           SELECT @n_err = 61119  
--                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
--                                            ': Insert Into TriganticLog Table (CCOUNT) Failed (ntrItrnAdd)' +  
--                                            ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
--                        END  
--                     END --  ( @n_continue = 1 or @n_continue = 2 )  
--                  END -- not exists  
               END -- if trigantic cc interface is on  
            END -- it source type = cc deposit  
         END -- ELSE @b_success <> 1  
      END -- @c_trantype='DP'  
      /* End Deposit Stuff */  
	  /* Withdrawal Stuff */  
      IF @c_trantype='WD'  
      BEGIN  
         SELECT @c_InsertStorerKey  = itrn.StorerKey  
              , @c_itrnkey          = itrn.itrnkey  
              , @c_InsertSku        = itrn.Sku  
              , @c_InsertLot        = itrn.Lot  
              , @c_InsertToLoc      = itrn.ToLoc  
              , @c_InsertToID       = itrn.ToID  
              , @c_InsertPackkey    = itrn.Packkey  
              , @n_casecnt          = itrn.casecnt  
              , @n_innerpack        = itrn.innerpack  
              , @n_Qty              = itrn.qty  
              , @n_pallet           = itrn.pallet  
              , @f_cube             = itrn.cube  
              , @f_grosswgt         = itrn.grosswgt  
              , @f_netwgt           = itrn.netwgt  
              , @f_otherunit1       = itrn.otherunit1  
              , @f_otherunit2       = itrn.otherunit2  
              , @c_status           = itrn.status  
              , @c_lottable01       = itrn.lottable01  
              , @c_lottable02       = itrn.lottable02  
              , @c_lottable03       = itrn.lottable03  
              , @d_lottable04       = itrn.lottable04  
              , @d_lottable05       = itrn.lottable05  
              , @c_lottable06       = itrn.lottable06    --(CS01)  
              , @c_lottable07       = itrn.lottable07    --(CS01)   
              , @c_lottable08       = itrn.lottable08    --(CS01)  
              , @c_lottable09       = itrn.lottable09    --(CS01) 
              , @c_lottable10       = itrn.lottable10    --(CS01)
              , @c_lottable11       = itrn.lottable11    --(CS01) 
              , @c_lottable12       = itrn.lottable12    --(CS01)
              , @d_lottable13       = itrn.lottable13    --(CS01)
              , @d_lottable14       = itrn.lottable14    --(CS01)
              , @d_lottable15       = itrn.lottable15    --(CS01)
              , @c_sourcekey        = itrn.sourcekey  
              , @c_sourcetype       = itrn.sourcetype  
              , @c_Channel          = itrn.Channel       --(SWT02)
              , @n_Channel_ID       = itrn.Channel_ID    --(SWT02)
           FROM ITRN WITH (NOLOCK)  
           JOIN INSERTED ON ( ITRN.itrnkey = INSERTED.itrnkey )  
  
         EXECUTE nspItrnAddWithDrawalCheck  
                 @c_itrnkey      = @c_itrnkey  
               , @c_StorerKey    = @c_InsertStorerKey  
               , @c_Sku          = @c_InsertSku  
               , @c_Lot          = @c_InsertLot  
               , @c_ToLoc        = @c_InsertToLoc  
               , @c_ToID         = @c_InsertToID  
               , @c_packkey      = @c_InsertPackKey  
               , @c_Status       = @c_status  
               , @n_casecnt      = @n_casecnt  
               , @n_innerpack    = @n_innerpack  
               , @n_Qty          = @n_Qty  
               , @n_pallet       = @n_pallet  
               , @f_cube         = @f_cube  
               , @f_grosswgt     = @f_grosswgt  
               , @f_netwgt       = @f_netwgt  
               , @f_otherunit1   = @f_otherunit1  
               , @f_otherunit2   = @f_otherunit2  
               , @c_lottable01   = @c_lottable01  
               , @c_lottable02   = @c_lottable02  
               , @c_lottable03   = @c_lottable03  
               , @d_lottable04   = @d_lottable04  
               , @d_lottable05   = @d_lottable05  
               , @c_lottable06   = @c_lottable06      --(CS01)  
               , @c_lottable07   = @c_lottable07      --(CS01)    
               , @c_lottable08   = @c_lottable08      --(CS01) 
               , @c_lottable09   = @c_lottable09      --(CS01)
               , @c_lottable10   = @c_lottable10      --(CS01)
               , @c_lottable11   = @c_lottable11      --(CS01)
               , @c_lottable12   = @c_lottable12      --(CS01)
               , @d_lottable13   = @d_lottable13      --(CS01)
               , @d_lottable14   = @d_lottable14      --(CS01)
               , @d_lottable15   = @d_lottable15      --(CS01)             
               , @c_sourcekey    = @c_sourcekey  
               , @c_sourcetype   = @c_sourcetype  
               , @c_Channel      = @c_Channel       --(SWT02)
               , @n_Channel_ID   = @n_Channel_ID      OUTPUT --(SWT02)                
               , @b_Success      = @b_success         OUTPUT  
               , @n_err          = @n_err             OUTPUT  
               , @c_errmsg       = @c_errmsg          OUTPUT  
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3 /* Other Error flags Set By nspItrnAddWithDrawalCheck */  
         END  
         -- Added By Shong for Hong Kong GDS Interface  
         -- Date 12th Sep 2001  
         -- begin  
         ELSE  
         BEGIN -- insert into transmitlog table for trantype = 'WD' and sourcetype = 'ntrPickDetail%'  
            -- Customize for HK Phase II, One World <> EXceed Interface  
            -- Begin  
            IF @c_sourcetype like 'ntrPickDetail%'  
            BEGIN  
               DECLARE @c_ExternOrderkey NVARCHAR(50),  --tlting_ext
                       @c_ExternLineNumber NVARCHAR(5),  
                       @c_OrderKey NVARCHAR(10), -- Added By June 7.Jan.02 -- (For OW Interface Phase II )  
                       @c_OrdType NVARCHAR(10),  
                        -- V5 (TH) Added By Ricky Start  
                       @c_orderlinenumber NVARCHAR(5)  

               --(Wan02) - START
               EXEC ispITrnSerialNoWithdrawal
                    @c_ITrnKey      = @c_ITrnKey
                  , @c_TranType     = @c_TranType
                  , @c_StorerKey    = @c_InsertStorerKey
                  , @c_Sku          = @c_InsertSku
                  , @n_Qty          = @n_Qty
                  , @c_SourceKey    = @c_SourceKey
                  , @c_SourceType   = @c_SourceType
                  , @b_Success      = @b_Success   OUTPUT  
                  , @n_Err          = @n_Err       OUTPUT  
                  , @c_ErrMsg       = @c_ErrMsg    OUTPUT

               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3 /* Other Error flags Set By nspItrnAddWithDrawalCheck */  
               END 
               --(Wan02) - END


               -- V5 (TH) Added By Ricky End  
               -- Get Storer Configuration -- One World Interface  
               -- Is One World Interface Turn On?  
               IF @c_authority_owitf = '1' AND @n_continue IN (1,2)  --(Wan02) 
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
                  SET @c_OrdType = '' -- SHONG01
                  
                  -- SHONG01
                  SELECT TOP 1  
                     @c_OrderKey = ORDERDETAIL.OrderKey, -- Changed By June 7.Jan.02 -- (For OW Interface Phase II : Changed from @c_externorderkey to @c_OrderKey)  
                      -- @c_ExternLineNo = ORDERDETAIL.ExternLineNo, -- Remark By June 7.Jan.02 -- (For OW Interface Phase II : Only Insert One Record For Each Orderkey)  
                     @c_OrdType  = ORDERS.Type  
                  FROM  ORDERDETAIL WITH (NOLOCK)  
                  JOIN ORDERS WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)  
                  JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey AND  
                                                   ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )  
                  WHERE PickDetailKey = SUBSTRING(@c_sourcekey,1, 10)  
  
                  IF @@ROWCOUNT > 0 AND @c_OrdType <> 'M'  
                  BEGIN  
                     -- Remark By June 7.Jan.02 (For OW Interface Phase II : Only Insert One record for Each Orderkey)  
                     EXEC dbo.ispGenTransmitLog 'OWORDSHIP', @c_OrderKey, '', '', ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61120  
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                         + ':Insert failed on TransmitLog (OWORDSHIP). (ntrItrnAdd) (SQLSvr MESSAGE='  
                                         + LTRIM(RTRIM(@c_errmsg)) + ')'  
                     END  
                  END -- if rowcount > 0 and type = ...  
               END -- one world interface  
            END -- sourcetype like 'ntrPickDetail%  
  
            -- SOS 20323: MXP Kitting confirmation  
            -- start: 20323  
            IF @c_sourcetype LIKE 'ntrKitDetail%'  
            BEGIN  
               IF @c_authority_mxpitf = '1'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
  
                  IF NOT EXISTS (SELECT 1 FROM transmitlog2 WITH (NOLOCK) WHERE TableName = 'MXPKIT'  
                                    AND Key1 = SUBSTRING(@c_sourcekey, 1, 10)  
                                    AND Key2 = SUBSTRING(@c_SourceKey, 11, 5)  
                                    AND Key3 = 'F')  
                  BEGIN  
                     EXECUTE nspg_getkey  
                     -- Change by June 15.Jun.2004  
                     -- To standardize name use in generating transmitlog2..transmitlogkey  
                     -- 'Transmitlog2Key'  
                            'TransmitlogKey2'  
                           , 10  
                           , @c_transmitlogkey OUTPUT  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61123  
                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                     END  
  
                     IF ( @n_continue = 1 OR @n_continue = 2 )  
                     BEGIN  
                        INSERT transmitlog2 (transmitlogkey,tablename,key1,key2,key3,transmitflag)  
                        VALUES (@c_transmitlogkey, 'MXPKIT', SUBSTRING(@c_sourcekey,1, 10),  
                                SUBSTRING(@c_SourceKey, 11, 5), 'F', '0')  
  
                        SELECT @n_err= @@Error  
                        IF NOT @n_err=0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61124  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                            ': Insert Into TransmitLog2 Table (ORDERS) Failed (ntrItrnAdd)' +  
                                            ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                        END  
                     END  
                  END  -- kit not exists in transmitlog2  
               END -- IF @c_authority_mxpitf = '1'  
            END -- IF @c_sourcetype LIKE 'ntrKitDetail%'  
            -- end : 20323  
  
            /* Modification - to add records in transmitlog */  
            -- Author : Shong Wan Toh  
            -- Purpose: One World Interface  
            -- Date   : 15th Dec 2001  
            IF @c_sourcetype LIKE 'ntrKitDetail%'  
            BEGIN  
               -- Get Storer Configuration -- One World Interface  
               -- Is One World Interface Turn On?  
               IF @c_authority_owitf = '1'  
               BEGIN  
                  SET @c_ITRNSourceKey = SUBSTRING(@c_SourceKey, 1, 10)  
                  SET @c_ITRNSourceKeyLineNum = SUBSTRING(@c_SourceKey, 11, 5)  
  
                  EXEC dbo.ispGenTransmitLog 'OWKIT', @c_ITRNSourceKey, @c_ITRNSourceKeyLineNum, 'F', ''  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
  
                  IF @b_success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61125  
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                      + ':Insert failed on TransmitLog (OWKIT). (ntrItrnAdd) (SQLSvr MESSAGE='  
                                      + LTRIM(RTRIM(@c_errmsg)) + ')'  
                  END  
               END -- if one world interface is on  
            END -- if source type = kitting  
  
            -- (ChewKP01) Start  
            IF @c_InsertBondSKU = '1' AND @n_continue IN (1,2)       --(Wan02) 
            BEGIN  
                     IF ISNULL(RTRIM(@c_lottable01),'') <> ''  
                     BEGIN  
                        -- (TK001)
                        Insert into BONDSKU ( itrnkey, StorerKey, Sku, busr5, itemclass, skugroup, style, color, size, measurement, status)
                        SELECT @c_itrnkey, @c_InsertStorerKey, @c_InsertSku,  busr5, itemclass, skugroup, style, color , size, measurement,'0'
                        FROM SKU WITH (NOLOCK)
                        WHERE Storerkey = @c_InsertStorerKey
                        AND SKU = @c_InsertSku
                     END  
            END  
            -- (ChewKP01) End  
         END -- else  
         -- end of customization  
      END  
      /* End Withdrawal Stuff */  
  
      /* Adjustment Stuff */  
      IF @c_trantype='AJ'  
      BEGIN  
         SELECT  @c_InsertStorerKey  = itrn.StorerKey  
               , @c_itrnkey          = itrn.itrnkey  
               , @c_InsertSku        = itrn.Sku  
               , @c_InsertLot   = itrn.Lot  
               , @c_InsertToLoc      = itrn.ToLoc  
               , @c_InsertToID       = itrn.ToID  
               , @c_InsertPackkey    = itrn.Packkey  
               , @n_casecnt          = itrn.casecnt  
               , @n_innerpack        = itrn.innerpack  
               , @n_Qty              = itrn.qty  
               , @n_pallet           = itrn.pallet  
               , @f_cube             = itrn.cube  
               , @f_grosswgt         = itrn.grosswgt  
               , @f_netwgt           = itrn.netwgt  
               , @f_otherunit1       = itrn.otherunit1  
               , @f_otherunit2       = itrn.otherunit2  
               , @c_status           = itrn.status  
               , @c_lottable01       = itrn.lottable01  
               , @c_lottable02       = itrn.lottable02  
               , @c_lottable03       = itrn.lottable03  
               , @d_lottable04       = itrn.lottable04  
               , @d_lottable05       = itrn.lottable05 
               , @c_lottable06       = itrn.lottable06      --(CS01)  
               , @c_lottable07       = itrn.lottable07      --(CS01)   
               , @c_lottable08       = itrn.lottable08      --(CS01)  
               , @c_lottable09       = itrn.lottable09      --(CS01) 
               , @c_lottable10       = itrn.lottable10      --(CS01)
               , @c_lottable11       = itrn.lottable11      --(CS01) 
               , @c_lottable12       = itrn.lottable12      --(CS01)
               , @d_lottable13       = itrn.lottable13      --(CS01)
               , @d_lottable14       = itrn.lottable14      --(CS01)
               , @d_lottable15       = itrn.lottable15      --(CS01) 
               , @c_sourcekey        = itrn.sourcekey  
               , @c_sourcetype       = itrn.sourcetype  
               , @c_Channel          = itrn.Channel       --(SWT02)
               , @n_Channel_ID       = itrn.Channel_ID    --(SWT02)               
           FROM ITRN WITH (NOLOCK)  
           JOIN INSERTED ON ( ITRN.itrnkey = INSERTED.itrnkey )  
  
         EXECUTE nspItrnAddAdjustmentCheck  
                 @c_itrnkey      = @c_itrnkey  
               , @c_StorerKey    = @c_InsertStorerKey  
               , @c_Sku          = @c_InsertSku  
               , @c_Lot          = @c_InsertLot  
               , @c_ToLoc        = @c_InsertToLoc  
               , @c_ToID         = @c_InsertToID  
               , @c_packkey      = @c_InsertPackKey  
               , @c_Status       = @c_status  
               , @n_casecnt      = @n_casecnt  
               , @n_innerpack    = @n_innerpack  
               , @n_Qty          = @n_Qty  
               , @n_pallet       = @n_pallet  
               , @f_cube         = @f_cube  
               , @f_grosswgt     = @f_grosswgt  
               , @f_netwgt       = @f_netwgt  
               , @f_otherunit1   = @f_otherunit1  
               , @f_otherunit2   = @f_otherunit2  
               , @c_lottable01   = @c_lottable01  
               , @c_lottable02   = @c_lottable02  
               , @c_lottable03   = @c_lottable03  
               , @d_lottable04   = @d_lottable04  
               , @d_lottable05   = @d_lottable05
               , @c_lottable06   = @c_lottable06      --(CS01)  
               , @c_lottable07   = @c_lottable07      --(CS01)    
               , @c_lottable08   = @c_lottable08      --(CS01) 
               , @c_lottable09   = @c_lottable09      --(CS01)
               , @c_lottable10   = @c_lottable10      --(CS01)
               , @c_lottable11   = @c_lottable11      --(CS01)
               , @c_lottable12   = @c_lottable12      --(CS01)
               , @d_lottable13   = @d_lottable13      --(CS01)
               , @d_lottable14   = @d_lottable14      --(CS01)
               , @d_lottable15   = @d_lottable15      --(CS01)  
               , @c_Channel      = @c_Channel         -- (SWT02)
               , @n_Channel_ID   = @n_Channel_ID      OUTPUT -- (SWT02)
               , @b_Success      = @b_success         OUTPUT  
               , @n_err          = @n_err             OUTPUT  
               , @c_errmsg       = @c_errmsg          OUTPUT  
  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3 /* Other Error flags Set By nspItrnAddAdjustmentCheck */  
         END  
         ELSE  
         BEGIN  
            -- Modified By SHONG on 09-Jul-2004  
            -- Adding Finalize Feature in Adjustment  
            -- Source Type will = ntrAdjustmentDetailUpdate if Finalize Adj is turn on  
            -- Else Source Type = ntrAdjustmentDetailAdd for Original  
            IF @c_sourcetype LIKE 'ntrAdjustmentDetail%'  
            BEGIN  
               -- Start - Add by June 14.APR.03  
               -- TBL HK - Outbound PIX  
               IF @c_authority_tblhkitf = '1'  
               BEGIN  
                  -- for Receipt Adjustment  
                  -- Modify by SHONG - Don't use NOT IN  
                  -- Modify by SHONG on 15-Jul-2003  
                  -- SOS# 12223, ignore any adjustment with Type = '99'.  
                  IF EXISTS (SELECT 1 FROM ADJUSTMENT WITH (NOLOCK)  
                             JOIN RECEIPT WITH (NOLOCK) ON ( CustomerRefNo = RECEIPT.Receiptkey )  
                             WHERE AdjustmentKey  =  SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                             AND   AdjustmentType <> '99')  
                  BEGIN  
                     SELECT @c_transmitlogkey=''  
                     SELECT @b_success=1  
                         
                     IF NOT EXISTS (SELECT 1 FROM TransmitLog2 WITH (NOLOCK) WHERE TableName = 'TBLADJ'  
                                    AND    Key1 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                                    AND    Key2 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 11, 5))  
                     BEGIN  
                        EXECUTE nspg_getkey  
                               'TransmitlogKey2'    -- Modified by YokeBeen on 5-May-2003  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61126  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
  
                        IF ( @n_continue = 1 OR @n_continue = 2 )  
                        BEGIN  
                           INSERT TransmitLog2 (transmitlogkey,tablename,key1,key2, key3)  
                           VALUES (@c_transmitlogkey, 'TBLADJ', SUBSTRING(@c_SourceKey, 1, 10),  
                                   SUBSTRING(@c_SourceKey, 11, 5), '' )  
  
                           SELECT @n_err= @@Error  
                           IF NOT @n_err=0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61127  
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                               ': Insert Into TransmitLog2 Table (TBLADJ) Failed (ntrItrnAdd)' +  
                                               ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                        END --  ( @n_continue = 1 or @n_continue = 2 )  
                     END -- not exists  
                  END -- Receipt Adj  
  
                  -- for Regular Adjustment  
                  -- Modify by SHONG on 15-Jul-2003  
                  -- SOS# 12223, ignore any adjustment with Type = '99'.  
                  IF EXISTS (SELECT 1 FROM ADJUSTMENT WITH (NOLOCK)  
                             LEFT OUTER JOIN RECEIPT WITH (NOLOCK) ON ( CustomerRefNo = RECEIPT.Receiptkey )  
                             WHERE AdjustmentKey  =  SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                             AND   AdjustmentType <> '99'  
                             AND   ISNULL(RECEIPT.ReceiptKey,'') = '')  
                  BEGIN  
                     SELECT @c_transmitlogkey=''  
                     SELECT @b_success=1  
                         
                     IF NOT EXISTS (SELECT 1 FROM TransmitLog2 WITH (NOLOCK) WHERE TableName = 'TBLREGADJ'  
                                    AND    Key1 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                                    AND    Key2 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 11, 5))  
                     BEGIN  
                        EXECUTE nspg_getkey  
                              'TransmitlogKey2'    -- Modified by YokeBeen on 5-May-2003  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61128  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
  
                        IF ( @n_continue = 1 OR @n_continue = 2 )  
                        BEGIN 
                           INSERT TransmitLog2 (transmitlogkey,tablename,key1,key2, key3)  
                           VALUES (@c_transmitlogkey, 'TBLREGADJ', SUBSTRING(@c_SourceKey, 1, 10),  
                                   SUBSTRING(@c_SourceKey, 11, 5), '' )  
  
                           SELECT @n_err= @@Error  
                           IF NOT @n_err=0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61129  
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                               ': Insert Into TransmitLog2 Table (TBLREGADJ) Failed (ntrItrnAdd)' +  
                                               ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                        END --  ( @n_continue = 1 or @n_continue = 2 )  
                     END -- not exists  
                  END -- Regular Adjustment  
               END -- if TBL HK interface is on  
               -- End - Add by June 14.APR.03  
  
               -- UHK begin  
               IF @c_authority_ulvitf = '1'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
  
                  -- SOS 8391 -- changed by Jeff -- ULV HK  
                  IF NOT EXISTS (SELECT 1 FROM ADJUSTMENT WITH (NOLOCK) WHERE Adjustmenttype = '10'  
                                    AND Adjustmentkey = SUBSTRING(@c_sourcekey, 1, 10) )  
                  BEGIN  
                     IF NOT EXISTS (SELECT 1 FROM TransmitLog2 WITH (NOLOCK) WHERE TableName = 'ULVADJ'  
                                    AND    Key1 = SUBSTRING(@c_sourcekey, 1, 10)  
                                    AND    Key2 = SUBSTRING(@c_sourcekey, 11, 5))  
                     BEGIN  
                        EXECUTE nspg_getkey  
                               'TransmitlogKey2'  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61130  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
  
                        IF ( @n_continue = 1 OR @n_continue = 2 )  
                        BEGIN  
                           BEGIN TRAN  
                           INSERT TransmitLog2 (transmitlogkey,tablename,key1,key2, key3)  
                           VALUES (@c_transmitlogkey, 'ULVADJ', SUBSTRING(@c_sourcekey,1, 10),  
                                   SUBSTRING(@c_sourcekey,11,5), @c_itrnkey )  
                           COMMIT TRAN  
  
                           SELECT @n_err= @@Error  
                           IF NOT @n_err=0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61131  
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                            ': Insert Into TransmitLog2 Table (ULVADJ) Failed (ntrItrnAdd)' +  
                                               ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                        END  
                     END  -- adjustment not exists in transmitlog table  
                  END -- if not exists (SELECT 1 from adjustment)...  
               END -- UHK Interface  
               -- UHK end  
  
               -- Get Storer Configuration -- One World Interface  
               -- Is One World Interface Turn On?  
               IF @c_authority_owitf = '1'  
               BEGIN  
                  -- Check if this adjustmenty type need to interface?  
                  IF EXISTS( SELECT 1 FROM ADJUSTMENT WITH (NOLOCK)  
                               JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = ADJUSTMENT.AdjustmentType AND  
                                                               CODELKUP.ListName = 'ADJTYPE' AND  
                                                               CODELKUP.LONG = 'OW')  
                              WHERE ADJUSTMENTKEY = SUBSTRING(@c_sourcekey, 1, 10))  
                  BEGIN  
                     SET @c_ITRNSourceKey = SUBSTRING(@c_SourceKey, 1, 10)  
                     SET @c_ITRNSourceKeyLineNum = SUBSTRING(@c_SourceKey, 11, 5)  
  
                     EXEC dbo.ispGenTransmitLog 'OWADJ', @c_ITRNSourceKey, @c_ITRNSourceKeyLineNum, @c_insertStorerkey, ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61132  
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                         + ':Insert failed on TransmitLog (OWADJ). (ntrItrnAdd) (SQLSvr MESSAGE='  
                                         + LTRIM(RTRIM(@c_errmsg)) + ')'  
                     END  
                  END -- Long = OW  
               END -- OW Interface  
               -- (YokeBeen01) - Start - Remarked on obsolete Configkey = 'GDSITF'  
               /*  
               ELSE IF @c_authority_gdsitf = '1'  
               BEGIN -- gds interface  
                  SELECT @c_adjtype = AdjustmentType  
                    FROM ADJUSTMENT WITH (NOLOCK)  
                   WHERE AdjustmentKey = SUBSTRING(@c_sourcekey,1,10)  
  
                  IF (@c_adjType = '01')  
                  BEGIN  
                     SELECT @c_transmitlogkey=''  
                     SELECT @b_success=1  
  
                     EXECUTE nspg_getkey  
                        'TransmitlogKey'  
                        , 10  
                        , @c_transmitlogkey OUTPUT  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61133  
                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                     END  
  
                     IF ( @n_continue = 1 OR @n_continue = 2 )  
                     BEGIN  
                        INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3)  
                        VALUES (@c_transmitlogkey, 'RCPTADJ', SUBSTRING(@c_sourcekey,1, 10),  
                                SUBSTRING(@c_sourcekey,11,5), @c_itrnkey )  
  
                        SELECT @n_err= @@Error  
                        IF NOT @n_err=0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61134  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                            ': Insert Into TransmitLog Table (RCPTADJ) Failed (ntrItrnAdd)' +  
                                            ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                        END  
                     END  
                  END -- adjtype = '01'  
               END -- IF @c_authority_gdsitf = '1'  
               */  
               -- (YokeBeen01) - End - Remarked on obsolete Configkey = 'GDSITF'  
               -- V5 (PH, TH, TW) Start 
               ELSE IF @c_authority_exeitf = '1'  
               BEGIN  
                  IF ( @n_continue = 1 OR @n_continue = 2 )  
                  BEGIN  
                     IF NOT EXISTS (SELECT 1 FROM TransmitLog WITH (NOLOCK) WHERE TableName = 'ADJ'  
                                    AND Key1 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 1, 10)  
                                    AND Key2 = SUBSTRING(ISNULL(RTRIM(@c_SourceKey),''), 11, 5))  
                     BEGIN  
                        EXECUTE nspg_getkey  
                               'TransmitlogKey'  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                    BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61135  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
  
                        IF ( @n_continue = 1 or @n_continue = 2 )  
                        BEGIN  
                           INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3)  
                           VALUES (@c_transmitlogkey, 'ADJ',SUBSTRING(@c_sourcekey,1, 10),  
                                   SUBSTRING(@c_sourcekey,11,5), @c_itrnkey )  
  
                           SELECT @n_err= @@Error  
                           IF NOT @n_err=0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61136  
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                               ': Insert Into TransmitLog Table (ADJ) Failed (ntrItrnAdd)' +  
                                               ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                  END -- IF ( @n_continue = 1 or @n_continue = 2 )  
                     END -- record not exists  
                  END -- IF ( @n_continue = 1 OR @n_continue = 2 )  
               END -- IF @c_authority_exeitf = '1'  
               -- V5 (PH, TH, TW) End  
  
               -- Added By Vicky PMTL ADJ EXP Start  
               IF @c_authority_pmtladj = '1'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
  
                  IF NOT EXISTS (SELECT 1 FROM TransmitLog WITH (NOLOCK) WHERE TableName = 'PMTLADJ'  
                                    AND Key1 = SUBSTRING(@c_sourcekey, 1, 10)  
                                    AND Key2 = SUBSTRING(@c_sourcekey, 11, 5))  
                  BEGIN  
                     EXECUTE nspg_getkey  
                            'TransmitlogKey'  
                           , 10  
                           , @c_transmitlogkey OUTPUT  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61137  
                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                     END  
  
                     IF ( @n_continue = 1 OR @n_continue = 2 )  
                     BEGIN  
                        INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3, transmitflag)  
                        VALUES (@c_transmitlogkey, 'PMTLADJ', SUBSTRING(@c_sourcekey,1, 10),  
                                SUBSTRING(@c_sourcekey,11,5), @c_itrnkey, '0' )  
  
                        SELECT @n_err= @@Error  
                        IF NOT @n_err=0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61138  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                            ': Insert Into TransmitLog Table (PMTLADJ) Failed (ntrItrnAdd)' +  
                                            ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                        END  
                     END  
                  END  -- adjustment not exists in transmitlog t  
               END -- Add By Vicky PMTL ADJ EXP END  
  
               -- Added By SHONG  
               -- For Trigantic PRoject  
               IF @c_authority_trigantic = '1'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
                  -- Check if this adjustmenty type need to interface?  
                  IF EXISTS( SELECT 1 FROM ADJUSTMENTDETAIL WITH (NOLOCK)  
                               JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = ADJUSTMENTDETAIL.ReasonCode AND  
                                                               CODELKUP.ListName = 'AdjReason' AND  
                                                               CODELKUP.SHORT = 'CC')  
                              WHERE ADJUSTMENTKEY = SUBSTRING(@c_sourcekey, 1, 10)  
                                AND AdjustmentLineNumber = SUBSTRING(@c_sourcekey, 11, 5))  
                     BEGIN 
                         
                     --TLTING03
                     IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) WHERE TableName = 'STSCCADJ'  
                                    AND DocumentNo = SUBSTRING(RTRIM(@c_SourceKey), 1, 10) 
                                    AND Key1       = SUBSTRING(RTRIM(@c_sourcekey), 11, 5) )  
                     BEGIN
                        SET @c_ITRNSourceKey = SUBSTRING(RTRIM(@c_SourceKey), 1, 10)  
                        SET @c_ITRNSourceKeyLineNum = SUBSTRING(RTRIM(@c_sourcekey), 11, 5) 
                        
                        EXEC ispGenDocStatusLog 'STSCCADJ', @c_InsertStorerKey, @c_ITRNSourceKey, @c_ITRNSourceKeyLineNum, @c_itrnkey,'0'
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
                  
                        IF @b_success <> 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=61139   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                           
                           SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                       ': Insert Failed On Table DocStatusTrack(STSCCADJ). (ntrItrnAdd)'+'('+  
                                       'SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'                                
                        END 
                     END -- not exists  
                     

--                     IF NOT EXISTS (SELECT 1 FROM TriganticLog WITH (NOLOCK) WHERE TableName = 'CCADJ'  
--                                    AND Key1 = SUBSTRING(@c_sourcekey, 1, 10)  
--                                    AND Key2 = SUBSTRING(@c_sourcekey, 11, 5))  
--                        BEGIN  
--                        EXECUTE nspg_getkey  
--                               'TRIGANTICKEY'  
--                              , 10  
--                              , @c_transmitlogkey OUTPUT  
--                              , @b_success OUTPUT  
--                              , @n_err OUTPUT  
--                              , @c_errmsg OUTPUT  
  
--                        IF NOT @b_success=1  
--                        BEGIN  
--                           SELECT @n_continue = 3  
--                           SELECT @n_err = 61139  
--                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
--                        END  
  
--                        IF ( @n_continue = 1 OR @n_continue = 2 )  
--                        BEGIN  
--                           INSERT TRIGANTICLOG (TriganticLogKey,tablename,key1,key2, key3, transmitflag)  
--                           VALUES (@c_transmitlogkey, 'CCADJ', SUBSTRING(@c_sourcekey,1, 10),  
--                                   SUBSTRING(@c_sourcekey,11,5), @c_itrnkey, '0' )  
  
--                           SELECT @n_err= @@Error  
--                           IF NOT @n_err=0  
--                           BEGIN  
--                              SELECT @n_continue = 3  
--                              SELECT @n_err = 61140  
--                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
--                                               ': Insert Into TraganticLog Table (CCADJ) Failed (ntrItrnAdd)' +  
--                                               ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
--                           END  
--                        END  
--                     END  -- adjustment not exists in transmitlog  
                  END  
               END -- IF @c_authority_trigantic = '1'  
               -- End Trigantic  
  
               -- SOS 20321: MXP Adjustment Confirmation  
               -- start: 20321  
               IF @c_authority_mxpitf = '1'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
  
                  IF NOT EXISTS (SELECT 1 FROM transmitlog2 WITH (NOLOCK)  
                                  WHERE TableName = 'MXPADJ' AND Key1 = SUBSTRING(@c_sourcekey, 1, 10))  
                  BEGIN  
                     EXECUTE nspg_getkey  
                     -- Change by June 15.Jun.2004  
                     -- To standardize name use in generating transmitlog2..transmitlogkey  
                     -- 'Transmitlog2Key'  
                            'TransmitlogKey2'  
                           , 10  
                           , @c_transmitlogkey OUTPUT  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61141  
                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                     END  
  
                     IF ( @n_continue = 1 OR @n_continue = 2 )  
                     BEGIN  
                        INSERT transmitlog2 (transmitlogkey,tablename,key1,transmitflag)  
                        VALUES (@c_transmitlogkey, 'MXPADJ', SUBSTRING(@c_sourcekey,1, 10), '0' )  
  
                        SELECT @n_err= @@Error  
                        IF NOT @n_err=0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61142  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                            ': Insert Into TransmitLog2 Table (MXPADJ) Failed (ntrItrnAdd)' +  
                                            ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                        END  
                     END  
                  END  -- adjustment not exists in transmitlog t  
               END  
               -- end: 20321  
  
               -- (ChewKP01) Start  
               IF @c_InsertBondSKU = '1'  
               BEGIN  
                  IF @n_Qty < 0  
                  BEGIN  
                     IF ISNULL(RTRIM(@c_lottable01),'') <> ''  
                     BEGIN  
                        -- (TK001)
                        Insert into BONDSKU ( itrnkey, StorerKey, Sku, busr5, itemclass, skugroup, style, color, size, measurement, status)
                        SELECT @c_itrnkey, @c_InsertStorerKey, @c_InsertSku,  busr5, itemclass, skugroup, style, color , size, measurement, '0'
                        FROM SKU WITH (NOLOCK)
                        WHERE Storerkey = @c_InsertStorerKey
                        AND SKU = @c_InsertSku
                     END  
                  END  
               END  
               -- (ChewKP01) End  
            END -- sourcetype like 'ntrAdjustmentDetailAdd%'  
         END  
      END  
      /* End Adjustment Stuff */  
  
      /* Moves Stuff */  
      IF @c_trantype='MV'  
      BEGIN  
         SET @c_MoveRefKey = ''                                            --(Wan01)
         SELECT  @c_InsertStorerKey  = itrn.StorerKey  
               , @c_itrnkey          = itrn.itrnkey  
               , @c_InsertSku        = itrn.Sku  
               , @c_InsertLot        = itrn.Lot  
               , @c_InsertFromLoc    = Itrn.FromLoc  
               , @c_InsertFromID     = Itrn.FromID  
               , @c_InsertToLoc      = itrn.ToLoc  
               , @c_InsertToID       = itrn.ToID  
               , @c_InsertPackkey    = itrn.Packkey  
               , @n_casecnt          = itrn.casecnt  
               , @n_innerpack        = itrn.innerpack  
               , @n_Qty              = itrn.qty  
               , @n_pallet           = itrn.pallet  
               , @f_cube             = itrn.cube  
               , @f_grosswgt         = itrn.grosswgt  
               , @f_netwgt           = itrn.netwgt  
               , @f_otherunit1       = itrn.otherunit1  
               , @f_otherunit2       = itrn.otherunit2  
               , @c_status           = itrn.status  
               , @c_lottable01       = itrn.lottable01  
               , @c_lottable02       = itrn.lottable02  
               , @c_lottable03    = itrn.lottable03  
               , @d_lottable04       = itrn.lottable04  
               , @d_lottable05       = itrn.lottable05 
               , @c_lottable06       = itrn.lottable06      --(CS01)  
               , @c_lottable07       = itrn.lottable07      --(CS01)   
               , @c_lottable08       = itrn.lottable08      --(CS01)  
               , @c_lottable09       = itrn.lottable09      --(CS01) 
               , @c_lottable10       = itrn.lottable10      --(CS01)
               , @c_lottable11       = itrn.lottable11      --(CS01) 
               , @c_lottable12       = itrn.lottable12      --(CS01)
               , @d_lottable13       = itrn.lottable13      --(CS01)
               , @d_lottable14       = itrn.lottable14      --(CS01)
               , @d_lottable15       = itrn.lottable15      --(CS01)  
               , @c_sourcekey        = itrn.sourcekey  
               , @c_sourcetype       = itrn.sourcetype 
               , @c_MoveRefKey       = ISNULL(RTRIM(ITRN.MoveRefKey),'')   --(Wan01) 
               , @c_Channel          = itrn.Channel         --(Wan03)
               , @n_Channel_ID       = itrn.Channel_ID      --(Wan03) 
               FROM ITRN WITH (NOLOCK)  
               JOIN INSERTED ON ( ITRN.itrnkey = INSERTED.itrnkey )  
  
         EXECUTE nspItrnAddMoveCheck  
                 @c_itrnkey      = @c_itrnkey  
               , @c_StorerKey    = @c_InsertStorerKey  
               , @c_Sku          = @c_InsertSku  
               , @c_Lot          = @c_InsertLot  
               , @c_fromloc      = @c_InsertFromLoc  
               , @c_fromid       = @c_InsertFromID  
               , @c_ToLoc        = @c_InsertToLoc  
               , @c_ToID         = @c_InsertToID  
               , @c_packkey      = @c_InsertPackKey  
               , @c_Status       = @c_status  
               , @n_casecnt      = @n_casecnt  
               , @n_innerpack    = @n_innerpack  
               , @n_Qty          = @n_Qty  
               , @n_pallet       = @n_pallet  
               , @f_cube         = @f_cube  
               , @f_grosswgt     = @f_grosswgt  
               , @f_netwgt       = @f_netwgt  
               , @f_otherunit1   = @f_otherunit1  
               , @f_otherunit2   = @f_otherunit2  
               , @c_lottable01   = @c_lottable01  
               , @c_lottable02   = @c_lottable02  
               , @c_lottable03   = @c_lottable03  
               , @d_lottable04   = @d_lottable04  
               , @d_lottable05   = @d_lottable05
               , @c_lottable06   = @c_lottable06      --(CS01)  
               , @c_lottable07   = @c_lottable07      --(CS01)    
               , @c_lottable08   = @c_lottable08      --(CS01) 
               , @c_lottable09   = @c_lottable09      --(CS01)
               , @c_lottable10   = @c_lottable10      --(CS01)
               , @c_lottable11   = @c_lottable11      --(CS01)
               , @c_lottable12   = @c_lottable12      --(CS01)
               , @d_lottable13   = @d_lottable13      --(CS01)
               , @d_lottable14   = @d_lottable14      --(CS01)
               , @d_lottable15   = @d_lottable15      --(CS01)   
               , @b_Success      = @b_success         OUTPUT  
               , @n_err          = @n_err             OUTPUT  
               , @c_errmsg       = @c_errmsg          OUTPUT  
               , @c_MoveRefKey   = @c_MoveRefKey      --(Wan01) 
               , @c_Channel      = @c_Channel                  --(Wan03)
               , @n_Channel_ID   = @n_Channel_ID      OUTPUT   --(Wan03) 

         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3 /* Other Error flags Set By nspItrnAddMoveCheck */  
         END  
         ELSE  
         BEGIN -- if successful, do interface  
            -- SOS 20323: MXP IQC confirmation  
            -- start: 20323  
            IF @c_SourceType = 'ntrInventoryQCDetailUpdate'  
            BEGIN  
               IF @c_authority_mxpitf = '1'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
  
                  IF NOT EXISTS (SELECT 1 FROM transmitlog2 WITH (NOLOCK) WHERE TableName = 'MXPIQC'  
                                    AND Key1 = SUBSTRING(@c_sourcekey, 1, 10)  
                                    AND Key2 = SUBSTRING(@c_SourceKey, 11, 5))  
                  BEGIN  
                     EXECUTE nspg_getkey  
                     -- Change by June 15.Jun.2004  
                     -- To standardize name use in generating transmitlog2..transmitlogkey  
                     -- 'Transmitlog2Key'  
                            'TransmitlogKey2'  
                           , 10  
                           , @c_transmitlogkey OUTPUT  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61143  
                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                     END  
  
                     IF ( @n_continue = 1 OR @n_continue = 2 )  
                     BEGIN  
                        INSERT transmitlog2 (transmitlogkey,tablename,key1,key2,transmitflag)  
                        VALUES (@c_transmitlogkey, 'MXPIQC', SUBSTRING(@c_sourcekey,1, 10),  
                                 SUBSTRING(@c_SourceKey, 11, 5), '0' )  
  
                        SELECT @n_err= @@Error  
                        IF NOT @n_err=0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61144  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                            ': Insert Into TransmitLog2 Table (MXPIQC) Failed (ntrItrnAdd)' +  
                                            ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                        END  
                     END  
                  END  -- iqc not exists in transmitlog2  
               END -- IF @c_authority_mxpitf = '1'  
            END -- IF @c_SourceType = 'ntrInventoryQCDetailUpdate'  
            -- end : 20323  
  
            IF @c_authority_owitf = '1'  
            BEGIN  
               IF @c_SourceType = 'ntrInventoryQCDetailUpdate'  
               BEGIN  
                  -- SOS#89405 Only send to OW is CODELKUP.LONG = 'OW'  
                  IF EXISTS( SELECT 1 FROM InventoryQC (NOLOCK)  
                  JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Code = InventoryQC.Reason AND  
                                 CODELKUP.ListName = 'IQCTYPE' AND  
                                 CODELKUP.LONG = 'OW')  
                            WHERE QC_Key = SUBSTRING(@c_sourcekey, 1, 10))  
                  BEGIN  
                     IF NOT EXISTS( SELECT 1 FROM Transmitlog WITH (NOLOCK) WHERE TableName = 'OWINVQC'  
                                       AND Key1 = SUBSTRING(@c_SourceKey, 1, 10)  
                                       AND Key2 = SUBSTRING(@c_SourceKey, 11, 5) )  
                     BEGIN  
                        SELECT @c_transmitlogkey=''  
                        SELECT @b_success=1  
  
                        EXECUTE nspg_getkey  
                               'TransmitlogKey'  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61145  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
  
                        IF ( @n_continue = 1 OR @n_continue = 2 )  
                        BEGIN  
                           -- Starts - Change by June 13.Mar.02 - HK Phase II  
                           -- If IQC.refno <> '', update flag to '0' if ASN transmitflag is '9' Else to '7'  
                           DECLARE @c_QCkey NVARCHAR(10), @c_receiptkey NVARCHAR(10), @c_transmitflag NVARCHAR(1)  
                           SELECT @c_QCKey = SUBSTRING(@c_SourceKey, 1, 10)  
  
                           IF EXISTS (SELECT 1 FROM INVENTORYQC WITH (NOLOCK)  
                                       WHERE qc_key = @c_QCKey AND ISNULL(LTRIM(RTRIM(TradeReturnKey)),'') <> '')  
                           BEGIN  
                              SELECT @c_receiptkey = TradeReturnKey  
                              FROM   INVENTORYQC WITH (NOLOCK)  
                              WHERE  qc_key = @c_QCkey  
  
                              -- Start : SOS36699  
                              IF EXISTS (SELECT 1 FROM RECEIPT WITH (NOLOCK) WHERE Receiptkey = @c_receiptkey)  
                              BEGIN  
                              -- End : SOS36699  
                                 IF EXISTS (SELECT 1 FROM TRANSMITLOG WITH (NOLOCK) WHERE key1 = @c_receiptkey  
                                               AND tablename = 'OWRCPT' AND transmitflag = '9')  
                                    SELECT @c_transmitflag = '0'  
                                 ELSE  
                                    SELECT @c_transmitflag = '7'  
                               -- Start : SOS36699  
                              END  
                              ELSE  
                              BEGIN  
                                 SELECT @c_transmitflag = '0'  
                              END  
                              -- End : SOS36699  
                           END  
                           ELSE  
                           BEGIN  
                              SELECT @c_transmitflag = '0'  
                           END   -- SOS# 181213  
                           BEGIN -- SOS# 181213  
                              -- End - Change by June 13.Mar.02 - HK Phase II  
                              -- Change by by June 13.Mar.02 - HK Phase II - Add in transmitflag  
                              INSERT TransmitLog (transmitlogkey,tablename,key1,key2, key3, transmitflag)  
                              VALUES (@c_transmitlogkey, 'OWINVQC', SUBSTRING(@c_SourceKey, 1, 10),  
                                      SUBSTRING(@c_SourceKey, 11, 5),@c_ItrnKey, @c_transmitflag )  
 
                              SELECT @n_err= @@Error  
                              IF NOT @n_err=0  
                              BEGIN  
                                 SELECT @n_continue = 3  
                                 SELECT @n_err = 61146  
                                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                                  ': Insert Into TransmitLog Table (OWINVQC) Failed (ntrItrnAdd)' +  
                                                  ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                              END  
                           END  
                        END  
                     END  -- adjustment not exists in transmitlog table  
                  END -- If Codelkup.Long = OW  
               END -- IF @c_SourceType = 'ntrInventoryQCDetailUpdate'  
  
               -- (YokeBeen04) - Start  
               IF @c_SourceType = 'rdtfnc_Move_UCC'  
               BEGIN  
                  IF @c_facility <> @c_facilityTo  
                  BEGIN  
                     EXEC dbo.ispGenTransmitLog 'OWUCCMV', @c_ItrnKey, '', @c_insertStorerKey, ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61147  
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                         + ':Insert failed on TransmitLog (OWUCCMV). (ntrItrnAdd) (SQLSvr MESSAGE='  
                                         + LTRIM(RTRIM(@c_errmsg)) + ')'  
                     END  
                  END -- IF @c_facility <> @c_facilityTo  
               END -- IF @c_SourceType = 'rdtfnc_Move_UCC'  
               -- (YokeBeen04) - End  
            END -- IF @c_authority_owitf = '1'  
            -- V5 (PH, TH) Start  
          ELSE IF @c_authority_exeitf = '1' AND @c_authority_ilsitf = '0'  
            BEGIN  
               SELECT @c_fromwhcode = HOSTWHCODE FROM LOC WITH (NOLOCK) WHERE LOC = @c_InsertFromLoc  
               SELECT @c_towhcode = HOSTWHCODE FROM LOC WITH (NOLOCK) WHERE LOC = @c_InsertToLoc  
  
               IF @c_fromwhcode <> @c_towhcode  
               BEGIN  
                  IF @c_trantype='MV' AND ( ISNULL(RTRIM(LTRIM(@c_sourcetype)),'') = '' )  
                                      AND ( ISNULL(RTRIM(LTRIM(@c_sourcekey)),'') = '' )  
                  BEGIN  
                     SELECT @c_transmitlogkey=''  
                     SELECT @b_success=1  
                     EXECUTE nspg_getkey  
                            'TransmitlogKey'  
                           , 10  
                           , @c_transmitlogkey OUTPUT  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                     IF NOT @b_success=1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61148  
                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                     END  
  
                     IF ( @n_continue = 1 or @n_continue = 2 )  
                     BEGIN  
                        INSERT TransmitLog (transmitlogkey,tablename,key1)  
                        VALUES (@c_transmitlogkey, 'WSMove',@c_itrnkey)  
  
                        SELECT @n_err= @@Error  
                        IF NOT @n_err=0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61149  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                            ': Insert Into TransmitLog Table (WSMove) Failed (ntrItrnAdd)' +  
                                            ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                        END  
                     END -- IF ( @n_continue = 1 or @n_continue = 2 )  
                  END  
               END -- fromwhcode <> towhcode  
            END -- IF @c_authority_exeitf = '1' AND @c_authority_ilsitf = '0'  
            -- V5 (PH, TH) End  
  
            -- Added by Vicky on 28-April-2006  
            -- For SOS#49377 (Start)  
            IF @c_authority_invmovlog = '1'
            BEGIN
               -- SOS#233138  
               SET @c_fromwhcode = ''  
               SET @c_towhcode = ''  
               SET @c_facility = ''  
               SET @c_facilityTo = ''  
  
               SELECT @c_fromwhcode = ISNULL(HOSTWHCODE, ''),      --(MC03)  
                      @c_FromLocationflag = LocationFlag, -- Added by Vicky on 27-Oct-2006 for SOS#61049  
                      @c_FromStatus = Status              -- Added by Vicky on 27-Oct-2006 for SOS#61049  
                    , @c_facility = Facility              -- SOS#233138  
               FROM  LOC WITH (NOLOCK)  
               WHERE LOC = @c_InsertFromLoc  
  
               SELECT @c_towhcode = ISNULL(HOSTWHCODE, ''),      --(MC03)  
                      @c_ToLocationflag = LocationFlag, -- Added by Vicky on 27-Oct-2006 for SOS#61049  
                      @c_ToStatus = Status              -- Added by Vicky on 27-Oct-2006 for SOS#61049  
                    , @c_facilityTo = Facility          -- SOS#233138  
               FROM LOC WITH (NOLOCK) WHERE LOC = @c_InsertToLoc  
  
               SELECT @c_FromIDStatus = Status  
               FROM ID WITH (NOLOCK)  
               WHERE ID = @c_InsertFromID  
  
               SELECT @c_ToIDStatus = Status  
               FROM ID WITH (NOLOCK)  
               WHERE ID = @c_InsertToID  
  
               SELECT @c_FromLotStatus = Status  
               FROM Lot WITH (NOLOCK)  
               WHERE Lot = @c_InsertLot  
  
               IF (@c_fromwhcode <> @c_towhcode) OR (@c_facility <> @c_facilityTo)  
               BEGIN  
                  IF @c_trantype='MV'  
                  BEGIN  
                     EXEC dbo.ispGenTransmitLog3 'INVMOVELOG', @c_itrnkey, '', @c_InsertStorerKey, ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err= 61150  
                        SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                          ':Insert failed on TransmitLog3. (ntrItrnAdd)'+  
                                          '(SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                     END  
                  END -- trantype = MV  
               END -- fromwhcode <> towhcode OR (@c_facility <> @c_facilityTo)  
  
               -- Added by Vicky on 27-Oct-2006 for SOS#61049 (Start)  
               IF (@c_authority_locflag = '1') AND  
                  (@c_fromwhcode = @c_towhcode ) -- Modified by Vicky 14-March-2007  
--                      (@c_fromwhcode = @c_towhcode AND @c_FromLocationflag = 'NONE' AND @c_ToLocationflag = 'HOLD' AND  
--                       @c_FromStatus <> 'HOLD' AND @c_ToStatus <> 'HOLD' AND @c_FromIDStatus <> 'HOLD' AND  
--                       @c_ToIDStatus <> 'HOLD' AND @c_FromLotStatus <> 'HOLD') OR  
--                      (@c_fromwhcode = @c_towhcode AND @c_FromLocationflag = 'HOLD' AND @c_ToLocationflag = 'NONE' AND  
--                       @c_FromStatus <> 'HOLD' AND @c_ToStatus <> 'HOLD' AND @c_FromIDStatus <> 'HOLD' AND  
--                       @c_ToIDStatus <> 'HOLD' AND @c_FromLotStatus <> 'HOLD')  
               BEGIN  
                  IF @c_trantype='MV'  
                  BEGIN  
                     EXEC dbo.ispGenTransmitLog3 'INVMOVELOG', @c_itrnkey, '', @c_InsertStorerKey, ''  
                        , @b_success OUTPUT  
                        , @n_err OUTPUT  
                        , @c_errmsg OUTPUT  
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err= 61151  
                        SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                          ':Insert failed on TransmitLog3. (ntrItrnAdd)'+  
                                          '(SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                     END  
                  END -- trantype = MV  
               END -- @c_authority_locflag <> '1'  
               -- Added by Vicky on 27-Oct-2006 for SOS#61049 (End)  
            END -- if @c_authority_invmovlog = '1'  
            -- For SOS#49377 (End)

            --(KH01) - Start
            IF @c_authority_wsinvmovlog = '1'
            BEGIN  
               SET @c_FromLocationCategory = ''  
               SET @c_FromLocationflag = ''  
               SET @c_ToLocationCategory = ''  
               SET @c_ToLocationflag = ''  
  
               SELECT @c_FromLocationCategory = LocationCategory
                    , @c_FromLocationflag = LocationFlag
               FROM  LOC WITH (NOLOCK)  
               WHERE LOC = @c_InsertFromLoc  
  
               SELECT @c_ToLocationCategory = LocationCategory
                    , @c_ToLocationflag = LocationFlag
               FROM LOC WITH (NOLOCK) WHERE LOC = @c_InsertToLoc 
  
               IF (@c_FromLocationCategory <> @c_ToLocationCategory) 
                  OR (@c_FromLocationflag <> @c_ToLocationflag)  
               BEGIN  
                  IF @c_trantype='MV'  
                  BEGIN  
                     EXEC dbo.ispGenTransmitLog2 'WSITRNLOGMOV', @c_itrnkey, '', @c_InsertStorerKey, ''  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT 
  
                     IF @b_success <> 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err= 61150  
                        SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                          ':Insert failed on TransmitLog2. (ntrItrnAdd)'+  
                                          '(SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                     END  
                  END -- trantype = MV  
               END -- (@c_FromLocationCategory <> @c_ToLocationCategory) OR (@c_FromLocationflag <> @c_ToLocationflag)  
            END -- if @c_authority_wsinvmovlog = '1'  
            --(KH01) - End

            --(KH02) - Start
            --IF @c_authority_wsinvmovwhcdlog = '1'                                     --(MC02)  
            --IF @c_authority_wsinvmovwhcdlog = '1' OR @c_authority_OMSITRNLOGMOV = '1'   --(MC02)
            IF (@c_authority_wsinvmovwhcdlog = '1'       --(YT01)
                OR @c_authority_wsinvmovwhcdlog2 = '1'   --(YT01)
                OR @c_authority_OMSITRNLOGMOV = '1')     --(YT01)
            BEGIN  
               SET @c_fromwhcode = ''  
               SET @c_towhcode = ''  
  
               SELECT @c_fromwhcode = ISNULL(HOSTWHCODE, '')      -- ZG01
               FROM  LOC WITH (NOLOCK)  
               JOIN ITRN WITH (NOLOCK) ON ITRN.FromLoc = Loc.Loc  -- ZG01 
               --WHERE LOC = @c_InsertFromLoc  
               WHERE ItrnKey = @c_itrnkey                         -- ZG01

               SELECT @c_towhcode = ISNULL(HOSTWHCODE, '')        -- ZG01
               FROM LOC WITH (NOLOCK) 
               JOIN ITRN WITH (NOLOCK) ON ITRN.ToLoc = Loc.Loc    -- ZG01 
               --WHERE LOC = @c_InsertToLoc 
               WHERE ItrnKey = @c_itrnkey                         -- ZG01
  
               IF (@c_fromwhcode <> @c_towhcode) 
               BEGIN  
                  IF @c_trantype='MV'  
                  BEGIN  
                     IF @c_authority_wsinvmovwhcdlog = '1' --(MC02)
                     BEGIN
                        EXEC dbo.ispGenTransmitLog2 'WSITRNLOGWHCDMOV', @c_itrnkey, '', @c_InsertStorerKey, ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT 
  
                        IF @b_success <> 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err= 61162  
                           SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                             ':Insert failed on TransmitLog2. (ntrItrnAdd)'+  
                                             '(SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                        END  
                     END

                     --(YT01)-S
                     IF @c_authority_wsinvmovwhcdlog2 = '1'
                     BEGIN
                        EXEC dbo.ispGenTransmitLog2 'WSITRNLOGWHCDMOV2', @c_itrnkey, '', @c_InsertStorerKey, ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT 
  
                        IF @b_success <> 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err= 61162  
                           SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                             ':Insert failed on TransmitLog2. (ntrItrnAdd)'+  
                                             '(SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                        END  
                     END
                     --(YT01)-E
                     
                     --(MC02) - S
                     IF @c_authority_OMSITRNLOGMOV = '1' 
                     BEGIN
                        EXEC dbo.ispGenTransmitLog2 'OMSITRNLOGMOV', @c_itrnkey, '', @c_InsertStorerKey, ''  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT 
  
                        IF @b_success <> 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err= 61162  
                           SELECT @c_errmsg= 'NSQL'+ISNULL(CONVERT(char(5), @n_err),'')+  
                                             ':Insert failed on TransmitLog2. (ntrItrnAdd)'+  
                                             '(SQLSvr MESSAGE='+ISNULL(LTRIM(RTRIM(@c_errmsg)),'')+')'  
                        END  
                     END
                     --(MC02) - E
                  END -- trantype = MV  
               END -- (@c_fromwhcode <> @c_towhcode)   
            END -- if @@c_authority_wsinvmovwhcdlog = '1'  
            --(KH02) - End

            -- (YokeBeen05) - Start  
            -- Added by MC on 09-May-2007  
            -- For SOS#75233 (Start)  
            IF (@c_authority_hwcdmvlog = '1') OR (@c_authority_owitf = '1') 
         OR (@c_authority_hwcdmv2log = '1') --(LL01)
            BEGIN  
               SELECT @c_fromwhcode = ISNULL(HOSTWHCODE, '')      --(MC03)
               FROM  LOC WITH (NOLOCK)  
               JOIN ITRN WITH (NOLOCK) ON ITRN.FromLoc = Loc.Loc  -- ZG01 
               --WHERE LOC = @c_InsertFromLoc  
               WHERE ItrnKey = @c_itrnkey                         -- ZG01
  
               SELECT @c_towhcode = ISNULL(HOSTWHCODE, '')        --(MC03)
               FROM  LOC WITH (NOLOCK) 
               JOIN ITRN WITH (NOLOCK) ON ITRN.ToLoc = Loc.Loc    -- ZG01
               --WHERE LOC = @c_InsertToLoc  
               WHERE ItrnKey = @c_itrnkey                         -- ZG01
  
               IF (@c_fromwhcode <> @c_towhcode)  
               BEGIN  
                  IF @c_trantype = 'MV'  
                  BEGIN  
                     IF (@c_authority_hwcdmvlog = '1')  
                     BEGIN  
                        EXEC dbo.ispGenTransmitLog3 'HWCDMVLOG', @c_itrnkey, '', @c_InsertStorerKey, ''  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                        IF @b_success <> 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61152  
                           SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                            + ':Insert failed on TransmitLog3. (ntrItrnAdd) (SQLSvr MESSAGE='  
                                            + LTRIM(RTRIM(@c_errmsg)) + ')'  
                        END  
                     END -- IF (@c_authority_hwcdmvlog = '1')  
                     ELSE IF (@c_authority_owitf = '1')  
                     BEGIN  
                        IF EXISTS ( SELECT 1 FROM STORERCONFIG WITH (NOLOCK)  
                                     WHERE StorerKey = @c_InsertStorerKey AND sValue = '1'  
                                       AND ConfigKey = 'OWHWCDMV' )  
                        BEGIN  
                           -- (YokeBeen06) - Start  
                           IF NOT EXISTS ( SELECT 1 FROM Transmitlog WITH (NOLOCK) WHERE TableName = 'OWINVQC'  
                                           AND Key3 = @c_itrnkey )  
                           BEGIN  
                              EXEC dbo.ispGenTransmitLog 'OWHWCDMV', @c_itrnkey, '', @c_InsertStorerKey, ''  
                                 , @b_success OUTPUT  
                                 , @n_err OUTPUT  
                                 , @c_errmsg OUTPUT  
  
                              IF @b_success <> 1  
                              BEGIN  
                                 SELECT @n_continue = 3  
                                 SELECT @n_err = 61153  
                                 SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                                  + ':Insert failed on TransmitLog. (ntrItrnAdd) (SQLSvr MESSAGE='  
                                                  + LTRIM(RTRIM(@c_errmsg)) + ')'  
                              END  
                           END -- IF Tablename = 'OWINVQC'  
                           -- (YokeBeen06) - End  
                        END -- -- IF ConfigKey = 'OWHWCDMV'  
                     END -- IF (@c_authority_owitf = '1') 
              --(LL01)-S
              IF (@c_authority_hwcdmv2log = '1')  
                     BEGIN  
                        EXEC dbo.ispGenTransmitLog3 'HWCDMV2LOG', @c_itrnkey, '', @c_InsertStorerKey, ''  
                           , @b_success OUTPUT  
                           , @n_err OUTPUT  
                           , @c_errmsg OUTPUT  
  
                        IF @b_success <> 1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61252  
                           SELECT @c_errmsg = 'NSQL' + CONVERT(char(5), @n_err)  
                                            + ':Insert failed on TransmitLog3. (ntrItrnAdd) (SQLSvr MESSAGE='  
                                            + LTRIM(RTRIM(@c_errmsg)) + ')'  
                        END  
                     END -- IF (@c_authority_hwcdmv2log = '1')  
              --(LL01)-E
                  END -- trantype = MV  
               END -- IF (@c_fromwhcode <> @c_towhcode)  
            END -- IF (@c_authority_hwcdmvlog = '1') OR (@c_authority_owitf = '1')  OR (@c_authority_hwcdmv2log = '1')
            -- For SOS#75233 (End)  
            -- (YokeBeen05) - End  
  
            -- Start - Add by June 15.APR.02  
            -- TBL HK - Outbound PIX  
            IF @c_authority_tblhkitf = '1'  
            BEGIN  
               -- Regular Move  
               IF  NOT EXISTS (SELECT 1 FROM transmitlog2 WITH (NOLOCK)  
                                WHERE key1 = @c_itrnkey AND TABLENAME = 'TBLREGMV')  
               BEGIN  
                  -- Alloc to Non-Alloc or Vice versa  
                  SELECT @n_FrFlag = CASE WHEN FrLoc.Locationflag IN ('HOLD', 'DAMAGED') THEN 1  
                                          WHEN FrLoc.Status = 'HOLD' THEN 1  
                                        --  WHEN MIN(FrID.Status) = 'HOLD' THEN 1 -- ONG01  
                                  ELSE 0 END  
                       , @n_ToFlag = CASE WHEN ToLoc.Locationflag IN ('HOLD', 'DAMAGED') THEN 1  
                                          WHEN ToLoc.Status = 'HOLD' THEN 1  
                                        --  WHEN MIN(ToID.Status) = 'HOLD' THEN 1 -- ONG01  
                                          ELSE 0 END  
                    FROM ITRN WITH (NOLOCK), LOC FrLoc WITH (NOLOCK), LOC ToLoc WITH (NOLOCK)  
                     -- , ID FrID (NOLOCK), ID ToID (NOLOCK)      -- ONG01  
                   WHERE ITRN.FromLoc = FrLoc.Loc  
                     AND ITRN.ToLoc = ToLoc.Loc  
                     -- AND  ITRN.FromID *= FrID.ID  AND  ITRN.ToID *= TOID.ID   -- ONG01  
                     AND ITRN.Itrnkey = @c_itrnkey  
                   GROUP BY FrLoc.Locationflag, ToLoc.Locationflag, FrLoc.Status, ToLoc.Status  
  
                  IF (@n_FrFlag <> @n_ToFlag)  
                  BEGIN  
                     SELECT @b_success = 1  
                     EXECUTE nspg_getkey  
                            'transmitlogkey2'    -- Modified by YokeBeen on 5-May-2003  
                           , 10  
                           , @c_transmitlogkey output  
                           , @b_success output  
                           , @n_err output  
                           , @c_errmsg output  
  
                     IF NOT @b_success = 1  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @n_err = 61154  
                        SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        --SELECT @n_err=63811   -- should be set to the sql errmessage but i don't know how to do so.  
                        --SELECT @c_errmsg = 'nsql' + convert(char(5),@n_err) + ': Unable To Obtain Transmitlogkey. (ntrItrnAdd)' + ' ( ' + ' sqlsvr message=' + ltrim(rtrim(@c_errmsg)) + ' ) '  
                     END  
                     ELSE  
                     BEGIN  
                        INSERT transmitlog2 (transmitlogkey, tablename, key1, transmitflag)  
                        VALUES (@c_transmitlogkey, 'TBLREGMV', @c_itrnkey, '0')  
  
                        SELECT @n_err= @@Error  
                        IF NOT @n_err=0  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61155  
                           SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                            ': Insert Into TransmitLog2 Table (TBLREGMV) Failed (ntrItrnAdd)' +  
                                            ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                        END  
                     END  
                  END -- Alloc to Non-Alloc or Vice versa  
               END -- TBLREGTRF  
            END -- TBLHKITF  
            -- End - Add by June 15.APR.02  (TBL HK - Outbound PIX)  
            -- V5 (TW) Start  
            ELSE  
            BEGIN  
               IF (@n_continue = 1 OR @n_continue = 2) AND @c_authority_ilsitf = '1'  
               BEGIN  
                  -- added by jeff, to insert into transmitlog table for Inventory Moves from different Host Warehouse Code  
                  -- start here  
                  -- For ILS - if this pallet is on hold, the Warehouse code should = 'H' follow by facility code  
                  -- IF to location with loseid set to on, then this pallet will automatically un-hold.  
                  -- WMS will send a acknowledgement to ILS to inform Logical Warehouse move from 'H' hold to 'M' normal  
  
                  SELECT @c_fromwhcode = HOSTWHCODE FROM LOC WITH (NOLOCK) WHERE LOC = @c_InsertFromLoc  
  
                  IF ISNULL(RTRIM(@c_InsertFromID),'') <> ''  
                  BEGIN  
                     IF EXISTS( SELECT ID FROM INVENTORYHOLD WITH (NOLOCK)  
                                 WHERE ID = @c_InsertFromID AND HOLD = '1' )  
                       BEGIN  
                        SELECT @c_FromWHCode = 'H' + Facility  
                          FROM LOC WITH (NOLOCK)  
                         WHERE LOC = @c_InsertFromLoc  
                       END  
                  END -- from id <> blank  
  
                  -- default host warehouse code from loc master  
                  -- Modified byh Shong  
                  -- Date: 10th May 2001  
                  -- Incident Ticket# 1046, submit by Danny  
                  -- Override Host Warehouse code if both id in on hold  
                  -- IF the pallet id is on-hold and the location not set to lost id, for ILS  
                  -- Hostwarehouse Code. It's still under 'H' Warehouse. Not trigger for move.  
  
                  IF EXISTS( SELECT 1 FROM ID WITH (NOLOCK), ITRN WITH (NOLOCK)  
                              WHERE ITRN.ITRNKEY = @c_itrnkey  
                                AND ID.ID = ITRN.ToID AND ID.STATUS = 'HOLD'  )  
                  BEGIN  
                     -- if id is on hold  
                     IF (SELECT LOSEID FROM LOC WITH (NOLOCK) WHERE LOC = @c_InsertToLoc) = '0'  
                     BEGIN  
                        -- if not lose id and id still on hold, then set warehouse code to 'H' + Facility  
                        SELECT @c_ToWHCode = 'H' + Facility  
                          FROM LOC WITH (NOLOCK)  
                         WHERE LOC = @c_InsertToLoc  
                     END  
                     ELSE  
                     BEGIN  
                        -- When lose id then set to normal warehouse code  
                        SELECT @c_towhcode = HOSTWHCODE  
                          FROM LOC WITH (NOLOCK)  
                         WHERE LOC = @c_InsertToLoc  
                     END  
                  END  
                  ELSE  
                  BEGIN  
                     SELECT @c_towhcode = HOSTWHCODE  
                       FROM LOC WITH (NOLOCK)  
                      WHERE LOC = @c_InsertToLoc  
                  END  
  
                  IF ISNULL(RTRIM(@c_fromwhcode),'') <> ISNULL(RTRIM(@c_towhcode),'')  
                  BEGIN  
                     IF @c_trantype='MV'  
                     BEGIN  
                        SELECT @c_transmitlogkey=''  
                        SELECT @b_success=1  
                        EXECUTE nspg_getkey  
                               'TransmitlogKey'  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61156  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
                        IF ( @n_continue = 1 OR @n_continue = 2 )  
                        BEGIN  
                           -- uses Key2 as a From HostWHCode and Key 3 as a To HostWHCode  
                           INSERT TransmitLog (transmitlogkey,tablename,key1, key2, key3, transmitbatch)  
                           VALUES (@c_transmitlogkey, 'WSMove',@c_itrnkey, @c_FromWHCode, @c_ToWHCode, @c_InsertToID)  
  
                           SELECT @n_err= @@Error  
                           IF NOT @n_err=0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err= 61157  
                              SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                               ': Insert Into TransmitLog Table (WSMove) Failed (ntrItrnAdd)' +  
                                               ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                        END  
                     END  
                  END -- fromwhcode <> towhcode  
               END -- IF (@n_continue = 1 OR @n_continue = 2) AND @c_authority_ilsitf = '1'  
            END -- IF @c_authority_tblhkitf <> '1'  
  
            -- Start (YokeBeen01 - SOS# /FBR8719)  
            IF @c_authority_ulvitf = '1'  
            BEGIN  
               IF @c_sourcetype LIKE 'ntrInventoryQCDetail%'  
               BEGIN  
                  SELECT @c_transmitlogkey=''  
                  SELECT @b_success=1  
  
                  IF EXISTS (SELECT 1 FROM INVENTORYQC WITH (NOLOCK)  
                              WHERE INVENTORYQC.QC_Key = SUBSTRING(@c_sourcekey, 1, 10)  
                                AND INVENTORYQC.StorerKey = @c_InsertStorerKey  
                                AND INVENTORYQC.Reason = 'TRANSFER')  
                  BEGIN  
                     IF NOT EXISTS (SELECT 1 FROM TransmitLog2 WITH (NOLOCK)  
                                     WHERE TransmitLog2.TableName = 'ULVIQCTRF'  
                                       AND TransmitLog2.Key1 = SUBSTRING(@c_sourcekey, 1, 10)  
                                       AND TransmitLog2.Key2 = SUBSTRING(@c_sourcekey, 11, 5))  
                     BEGIN  
                        EXECUTE nspg_getkey  
                               'TransmitlogKey2'  
                              , 10  
                              , @c_transmitlogkey OUTPUT  
                              , @b_success OUTPUT  
                              , @n_err OUTPUT  
                              , @c_errmsg OUTPUT  
  
                        IF NOT @b_success=1  
                        BEGIN  
                           SELECT @n_continue = 3  
                           SELECT @n_err = 61158  
                           SELECT @c_errmsg = 'ntrItrnAdd: ' + ISNULL(RTRIM(@c_errmsg),'')  
                        END  
  
                        IF ( @n_continue = 1 OR @n_continue = 2 )  
                        BEGIN  
                           BEGIN TRAN  
                           INSERT TransmitLog2 (transmitlogkey,tablename,key1,key2, key3)  
                           VALUES (@c_transmitlogkey, 'ULVIQCTRF', SUBSTRING(@c_sourcekey,1, 10),  
                                   SUBSTRING(@c_sourcekey,11,5), @c_itrnkey )  
                           COMMIT TRAN  
  
                           SELECT @n_err= @@Error  
                           IF NOT @n_err=0  
                           BEGIN  
                              SELECT @n_continue = 3  
                              SELECT @n_err = 61159  
                              SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),ISNULL(@n_err,0))  
                                               + ': Insert Into TransmitLog2 Table (ULVIQCTRF) Failed (ntrItrnAdd)'  
                                               + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                           END  
                        END  
                     END  -- InventoryQC not exists in transmitlog table  
                  END -- Check for valid Reason = 'TRANSFER'  
               END -- UHK Interface  
            END  
            -- End (YokeBeen01 - SOS# /FBR8719)  
            -- V5 (HK) End  
  
            --  (YokeBeen02) - Start  
            IF @c_authority_nikeregitf = '1'  
            BEGIN  
               -- Move  
               -- (YokeBeen03) - Start  
               -- Inventory to OnHold/Release should based on Facility level  
               SELECT @n_FrFlag = CASE WHEN FrLoc.Locationflag IN ('HOLD', 'DAMAGE') THEN 1  
                                       WHEN FrLoc.Status = 'HOLD' THEN 1  
                                       WHEN MIN(FrID.Status) = 'HOLD' THEN 1  
                                       ELSE 0 END,  
                      @n_ToFlag = CASE WHEN ToLoc.Locationflag IN ('HOLD', 'DAMAGE') THEN 1  
                                       WHEN ToLoc.Status = 'HOLD' THEN 1  
                                       WHEN MIN(ToID.Status) = 'HOLD' THEN 1  
                                       ELSE 0 END,  
                      @c_xFacility = FrLoc.Facility  
               FROM ITRN WITH (NOLOCK)  
               JOIN LOC FrLoc WITH (NOLOCK) ON (ITRN.FromLoc = FrLoc.Loc)  
               JOIN LOC ToLoc WITH (NOLOCK) ON (ITRN.ToLoc = ToLoc.Loc)  
               LEFT OUTER JOIN ID FrID WITH (NOLOCK) ON (ITRN.FromID = FrID.ID)  
               LEFT OUTER JOIN ID ToID WITH (NOLOCK) ON (ITRN.ToID = TOID.ID)  
               WHERE ITRN.Itrnkey = @c_itrnkey  
               GROUP BY FrLoc.Locationflag, ToLoc.Locationflag, FrLoc.Status, ToLoc.Status, FrLoc.Facility  
  
               -- UnHold to Hold or Hold to UnHold  
               IF ((@n_FrFlag = 0) AND (@n_ToFlag = 1)) OR ((@n_FrFlag = 1) AND (@n_ToFlag = 0))  
               BEGIN  
                  BEGIN TRAN  
                     INSERT INTO INVHOLDTRANSLOG  
                                (StorerKey, Sku, Facility, SourceKey, SourceType, UserID)  
                     VALUES (@c_InsertStorerKey, @c_InsertSku, @c_xFacility, @c_itrnkey, 'ITRN-MOVE', SUSER_SNAME())  
                  COMMIT TRAN  
  
                  SELECT @n_err= @@Error  
                  IF NOT @n_err=0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61160  
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                      ': Insert Into INVHOLDTRANSLOG Table (ITRN-MOVE) Failed (ntrItrnAdd)' +  
                                      ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                  END  
               END  
               -- (YokeBeen03) - End  
            END -- IF @c_authority_nikeregitf = '1'  
            --  (YokeBeen02) - End  
  
            -- --  Added by MaryVong on 09-Jun-2004 (IDSHK-Nuance Watson: Putaway Export) - Start(2)  
            IF @c_authority_nwitf = '1'  
            BEGIN  
               -- Get location types  
               SELECT @c_FrLocType =  
                        CASE WHEN (FrLoc.Locationflag = 'HOLD' AND FrLoc.PutawayZone = '0000') THEN 'RcvHoldLoc'  
                             WHEN (FrLoc.Locationflag = 'HOLD' AND FrLoc.PutawayZone = 'NWSTAGE') THEN 'StorageLoc'  
                             WHEN (FrLoc.Locationflag = 'NONE' AND FrLoc.PutawayZone <> '0000') THEN 'StorageLoc'  
                             WHEN (FrLoc.Locationflag IN ('HOLD','DAMAGE') AND FrLoc.PutawayZone <> '0000') THEN 'HoldDmgLoc'  
                             ELSE ''  
                        END,  
                      @c_ToLocType =  
                        CASE WHEN (ToLoc.Locationflag = 'HOLD' AND ToLoc.PutawayZone = '0000') THEN 'RcvHoldLoc'  
                             WHEN (ToLoc.Locationflag = 'HOLD' AND ToLoc.PutawayZone = 'NWSTAGE') THEN 'StorageLoc'  
                             WHEN (ToLoc.Locationflag = 'NONE' AND ToLoc.PutawayZone <> '0000') THEN 'StorageLoc'  
                             WHEN (ToLoc.Locationflag IN ('HOLD','DAMAGE') AND ToLoc.PutawayZone <> '0000') THEN 'HoldDmgLoc'  
                             ELSE ''  
                        END,  
                      @c_FrShort = FrCode.Short,  
                      @c_ToShort = ToCode.Short  
                 FROM ITRN WITH (NOLOCK)  
                 JOIN LOC FrLoc WITH (NOLOCK) ON ITRN.FromLoc = FrLoc.Loc  
                 JOIN LOC ToLoc WITH (NOLOCK) ON ITRN.ToLoc = ToLoc.Loc  
                 JOIN CODELKUP FrCode WITH (NOLOCK) ON FrLoc.Putawayzone = FrCode.Code AND FrCode.ListName = 'NWZONE'  
                 JOIN CODELKUP ToCode WITH (NOLOCK) ON ToLoc.Putawayzone = ToCode.Code AND ToCode.ListName = 'NWZONE'  
                WHERE ITRN.Itrnkey = @c_itrnkey  
  
               -- Only insert records while move from diff. location type, and location type is not empty  
               IF (@c_FrLocType <> @c_ToLocType) AND  
                  (@c_FrLocType <> '') AND  
                  (@c_ToLocType <> '') AND  
                  (@c_FrShort <> @c_ToShort) -- SOS 26475 wally 25.aug.04  
               BEGIN  
                  SELECT @b_success=1  
  
                  -- SOS 27626 -- Nuance outbound interface modification (done by local IT)  
                  EXEC ispGenTransmitLog3 'NWPUTAWAY'  
                     , @c_itrnkey            -- Key1  
                     , ''                    -- Key2  
                     , @c_InsertStorerKey    -- Key3  
                     , ''  
                     , @b_success OUTPUT  
                     , @n_err OUTPUT  
                     , @c_errmsg OUTPUT  
  
                  IF NOT @b_success=1  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @n_err = 61161  
                     SELECT @c_errmsg ='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+  
                                       ': Insert Into TransmitLog3 Table (NWPUTAWAY) Failed (ntrItrnAdd)' +  
                                       ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                  END  
               END  -- sourcetype = ''  
            END -- IF @c_authority_nwitf = '1'  
            -- Added by MaryVong on 09-Jun-2004 (IDSHK-Nuance Watson: Putaway Export) - End(2)  
         END -- @b_Success = 1  
      END  -- IF @c_trantype='MV'  
      /* End Moves Stuff */  
  
      /* Suspense Stuff */  
      IF @c_trantype='SU'  
      BEGIN  
         PRINT 'SU Not Done Yet'  
      END  
      /* End Suspense Stuff */  
   END  
   /* Main Processing ends */  
  
   /* Post Process Starts */  
   /* #INCLUDE <TRIA2.SQL> */  
   /* Post Process Ends */  
  
   /* Return Statement */  
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrItrnAdd'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
         RETURN  
      END  
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