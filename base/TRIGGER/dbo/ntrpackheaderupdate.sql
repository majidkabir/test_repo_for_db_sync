SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Trigger: ntrPackHeaderUpdate                                               */
/* Creation Date:                                                             */
/* Copyright: IDS                                                             */
/* Written by:                                                                */
/*                                                                            */
/* Purpose:                                                                   */
/*                                                                            */
/* Input Parameters: NONE                                                     */
/*                                                                            */
/* OUTPUT Parameters: NONE                                                    */
/*                                                                            */
/* Return Status: NONE                                                        */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/* Local Variables:                                                           */
/*                                                                            */
/* Called By: When records updated                                            */
/*                                                                            */
/* PVCS Version: 1.16                                                         */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */
/* 15-Jun-2005  June             Script merging : SOS18664 done by Wanyt      */
/* 26-Oct-2005  YokeBeen         Added Drop SP & Grant Access to NSQL Group.  */
/* 04-Apr-2007  MaryVong         Update PickingInfo when ScanOutDate is NULL  */
/* 05-Apr-2007  MaryVong         Add in RDT compatible error message          */
/* 11-Apr-2007  Shong            Performance Tuning  (Shong01)                */
/* 07-Jan-2009  James            Delete those packdetail line with sku = '' if*/
/*                               config 'RDTDYNAMICPICK' turned on (james01)  */
/* 02-Feb-2009  TLTING           With (Rowlock) (tlting01)                    */
/* 03-Jul-2009  Shong            CMS - Capture PackHeader Summary SOS140791   */
/* 20-Aug-2009  NJOW01           Update MBOL Total Carton on Pack Confirm in  */
/*                               Precartonize Packing Screen (SOS#140938)     */
/* 26-Jul-2010  NJOW01           183212 - Allow pack after scan in and B4 ship*/
/* 10-Feb-2011  TLTING     1.5   SOS# 202359 - Initialize variable  (TLTING01)*/
/* 03-May-2011  Leong      1.6   SOS# 213276 - Update TotalCartons for        */
/*                                             multiple pickslip per Orders   */
/* 25-May-2011  SPChin     1.7   SOS215633 - Bug Fixed                        */
/* 25-May-2011  Ung        1.8   SOS216105 Configurable SP to calc            */
/*                               carton, cube and weight                      */
/* 13-Dec-2011  ChewKP     1.9   SOS#229834 - Add PACKORDLOG for PackConfirm  */
/*                               (ChewKP01)                                   */
/* 28-Dec-2011  James      2.0   Bug fix (james02)    */
/* 30-Dec-2011  Shong      2.1   Calculate TotalCartons for Pick Confirmed    */
/* 31-Dec-2011  Shong      2.2   Update PackHeader.TTLCNTS When Pick Confirm  */
/* 10-01-2012   ChewKP     2.3   Standardize ConsoOrderKey Mapping            */
/*                               (ChewKP02)                                   */
/* 23-Apr-2012  NJOW03     2.4   241032-Calculation by coefficient            */
/* 22-May-2012  TLTING02   2.5   DM integrity - add update editdate B4        */
/*                               TrafficCop check                             */
/* 28-May-2012  YTWan      1.13  SOS#239595(ScanNPack). Put Back code to      */
/*                               Update PackHeader CTNTYP1 and CTNCNT1 if     */
/*                               CMSPackingFormula is not setup. (Wan01)      */
/* 15-Jun-2012  YTWan      1.14  SOS#246450: Delete ShortPicks & PackConfirm  */
/*                               from MBOL / CBOL. (Wan02)                    */
/* 25-Jun-2012  NJOW04     1.15  247575-IDSUS - Prevent Carton Finalize if    */
/*                               having missing UPS Tracking #                */
/* 05-Sep-2012  NJOW05     1.16  247575 - Fix checking storerconfig CHKUPSDATA*/
/* 26-Sep-2012  MCTang     1.17  SOS#252143 - Add PACKEDLOG (MC01)            */
/* 19-JUN-2013  YTWan      1.18  SOS#281443 - Add Storerconfig - "UpdCtnXLoad"*/
/*                               to Stamp unique carton# to refno2 for  Dropid*/
/*                               (Wan03)                                      */
/*                         1.19  Fixed refno2 count up to 10 only (Wan04)     */
/* 28-Oct-2013  TLTING     1.20  Review Editdate column update                */
/* 06-Feb-2013  YTWan      1.21  SOS#301554: VFCDC - Update UCC when Pack     */
/*                               confirm in Exceed. (Wan05)                   */
/* 18-NOV-2014  YTWan      1.22  SOS#326107 - [NIKE] Change Logic to update   */
/*                               carton no for Storerconfig (Wan06)           */
/* 16-Apr-2015  SHONG02    1.23  Performance Tuning                           */
/* 19-Aug-2015  SHONG03    1.24  Added Backend Pick Confirm                   */
/* 12-Oct-2015  NJOW06     1.25  354439-Pack confirm delete empty item line   */
/* 21-Jun-2016  Wan07      1.26  Performance tune                             */
/* 08-Mar-2015  NJOW07     1.27  365438-CN-LULU-Fedex. Add Packed2Log to      */
/*                               transmitlog3                                 */
/* 22-Sep-2016  SHONG04    1.28  Only allow backend pack confirm for ECOM     */
/* 29-Sep-2016  SHONG04    1.29  Perfromance Tune                             */
/* 16-May-2017  NJOW08     1.30  Allow config to call custom sp               */
/* 23-May-2017  Ung        1.31  WMS-1919 Add serial no, PackStatus           */
/* 16-AUG-2017  Shong      1.32  Not allow update ArchiveCop to 9 if status=0 */
/*                               SWT01                                        */
/* 25-Jul-2017  NJOW09     1.33  WMS-1742 Archivecop mode still allow run     */
/*                               custom trigger sp if the config is turned on */
/*----------------------------------------------------------------------------*/
/* Revised Ver base on PVCS version                                           */
/* 28-Aug-2017  YokeBeen   1.10  Revised and moved trigger points to a Sub-SP */
/*                               - isp_ITF_ntrPackHeader - (YokeBeen01).      */
/* 20-Aug-2019  WLChooi    1.11  WMS-9973 - Pack Confirm Extended Validation  */
/*                               (WL01)                                       */
/* 21-Apr-2020  WLChooi    1.12  Bug Fix for WMS-9973 (WL02)                  */
/* 19-Jun-2020  TLTING03   1.13  Deadlock tune                                */ 
/* 26-Aug-2020  TLTING04   1.14  Missing NOLOCK                               */ 
/* 30-Oct-2020  LiLiChua   1.15  LFI-330 - Add new trigger PACKORD2LG (LL01)  */
/* 07-Sep-2020  WLChooi    1.16  WMS-15016 - Rearrange Carton Number upon Pack*/
/*                               Confirm (WL03)                               */
/******************************************************************************/

CREATE TRIGGER [dbo].[ntrPackHeaderUpdate]
ON [dbo].[PackHeader]
FOR  UPDATE
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

   DECLARE @b_Success   int,           -- Populated by calls to stored procedures - was the proc successful?
           @n_err       int,           -- Error number returned by stored procedure or this trigger
           @c_errmsg    NVARCHAR(250), -- Error message returned by stored procedure or this trigger
           @n_continue  int,           -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
           @n_starttcnt int,           -- Holds the current transaction count
           @n_cnt       int,           -- Holds the number of rows affected by the Update statement that fired this trigger.
           @c_ArchiveCopAllowTriggerSP NVARCHAR(10) --NJOW09

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @b_success=0, @n_err=0, @c_errmsg=''

   DECLARE @c_ArchiveCop         NVARCHAR(10) = ''
         , @c_InsertedStatus     NVARCHAR(10) = ''
         , @c_TracePSNo          NVARCHAR(10) = ''

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)      --SWT01
   BEGIN
   	  --NJOW09
      IF EXISTS (SELECT 1 FROM INSERTED i   
                   JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey    
                   JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                  WHERE s.configkey = 'PackHeaderTrigger_SP' AND i.ArchiveCop IS NULL) 
      BEGIN
         BEGIN TRAN
         SELECT @c_ArchiveCopAllowTriggerSP = 'Y'
      END
   	
      SELECT @c_ArchiveCop = ISNULL(ArchiveCop,'')
           , @c_InsertedStatus = ISNULL([Status],'')
        FROM INSERTED
       WHERE ArchiveCop IS NOT NULL
         AND ArchiveCop = '9'

      SELECT @c_TracePSNo = ISNULL(PickSlipNo,'')
        FROM INSERTED

      IF @c_InsertedStatus <> '9' AND ISNULL(@c_ArchiveCop,'') <> ''
      BEGIN
         EXEC isp_Sku_Log '', @c_TracePSNo, 'UPD-PackHeader', @c_InsertedStatus, @c_ArchiveCop --L01
      END
      SELECT @n_continue = 4
   END

   --IF UPDATE(ArchiveCop)
   --BEGIN
   --   SELECT @n_continue = 4
   --END

   -- tlting02
   IF  EXISTS ( SELECT 1 FROM INSERTED, DELETED
                 WHERE INSERTED.Pickslipno = DELETED.Pickslipno
                   AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) )
                   AND ( @n_continue = 1 OR @n_continue = 2  )
                   AND NOT UPDATE(EditDate)
   BEGIN
      -- Added by YokeBeen on 19-Sept-2003 for EditDate updating - Start
      UPDATE PACKHEADER with (ROWLOCK)
         SET EditDate = GETDATE() ,
             EditWho = SUser_SName(),
             ArchiveCop = PACKHEADER.ArchiveCop
        FROM PACKHEADER
        JOIN INSERTED ON (PACKHEADER.Pickslipno = INSERTED.Pickslipno)
       WHERE PACKHEADER.Status < '9'
      -- Added by YokeBeen on 19-Sept-2003 for EditDate updating - End

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109651
         SELECT @c_errmsg ='NSQL'+ CONVERT(char(6), @n_err) + ': Update Failed On Table PACKHEADER. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      END
   END

   IF @n_continue = 1 OR @n_continue = 2                 --(Wan07) Not to start begin tran if update archivecop
   BEGIN                                                 --(Wan07)
      BEGIN TRAN

      DECLARE @c_PickSlipNo               NVARCHAR(10),
              @c_OrderKey                 NVARCHAR(10),
              @c_loadkey             NVARCHAR(10),
              @c_Storerkey                NVARCHAR(20), -- Added By Vicky 08 May 2003 - Exceed V5.1
              @c_authority                NVARCHAR(1),  -- Added By Vicky 08 May 2003 - Exceed V5.1
              @c_DisableAutoPickAfterPack NVARCHAR(1),  -- NJOW01
              @c_facility                 NVARCHAR(5),  -- NJOW01
              @c_authority_packordlog     NVARCHAR(1),  -- (ChewKP01) -- Generic PackConfirmLog
				  @c_authority_packord2lg     NVARCHAR(1),  -- (LL01)
              @c_PackStatus               NVARCHAR(10)

      --WL01 Start
      DECLARE @c_GetOrderkey              NVARCHAR(10), -- (WL01)
              @b_IsConso                  INT = 0,      -- (WL01)
              @c_Configkey                NVARCHAR(50), -- (WL01)
              @c_GetAuthority             NVARCHAR(30)  -- (WL01)
      --WL01 End

      DECLARE @c_CartonGroup              NVARCHAR(10),
              @c_CartonType               NVARCHAR(10),
              @n_CartonCube               float,
              @n_TotalWeight              float,
              @n_PackedCube               float,
              @n_TotalCube                float,
              @n_TotalCarton              int,
              @cDefaultCartonType         NVARCHAR(10),
              @nPackDetCtn                int,
              @cCtnTyp1                   NVARCHAR(10),
              @cCtnTyp2                   NVARCHAR(10),
              @cCtnTyp3                   NVARCHAR(10),
              @cCtnTyp4                   NVARCHAR(10),
              @cCtnTyp5                   NVARCHAR(10),
              @nCtnCnt1                   int,
              @nCtnCnt2                   int,
              @nCtnCnt3                   int,
              @nCtnCnt4                   int,
              @nCtnCnt5                   int,
              @nCtnCnt                    int,
              @nCartonCnt                 int,
              @nCartonWeight              float,
              @cSP_Carton                 SYSNAME,        -- SOS216105
              @cSP_Cube                   SYSNAME,        -- SOS216105
              @cSP_Weight                 SYSNAME,        -- SOS216105
              @cSQL                       NVARCHAR( 400), -- SOS216105
              @cParam                     NVARCHAR( 400), -- SOS216105
              @cSValue                    NVARCHAR( 10),  -- SOS216105
              @c_ConsoOrderKey            NVARCHAR(30),   -- (ChewKP01) -- (ChewKP02)
              @c_COrderKey                NVARCHAR(10),   -- (ChewKP01)
              @c_TSConsoOrderKey          NVARCHAR(30),   -- (ChewKP01) -- (ChewKP02)
              @c_TSOrderKey               NVARCHAR(10),   -- (ChewKP01)
              @n_Coefficient_carton       float,          --NJOW03
              @n_Coefficient_cube         float,          --NJOW03
              @n_Coefficient_weight       float,          --NJOW03
              @c_authority_chkupsdata     VARCHAR(10),    --NJOW04
              @c_ordertype                VARCHAR(10),    --NJOW04
              @c_upsrtn                   VARCHAR(18),    --NJOW04
              @n_cartonno                 int,            --NJOW04
              @c_PackConfirmDelEmptyLine  NVARCHAR(10)    --NJOW06
            , @n_RefNo2                   INT             --(Wan03)
            , @c_DropID                   NVARCHAR(20)    --(Wan03)

      -- SHONG02 Performance Tuning
      DECLARE
              @cPH_CtnTyp1                NVARCHAR(10),
              @cPH_CtnTyp2                NVARCHAR(10),
              @cPH_CtnTyp3                NVARCHAR(10),
              @cPH_CtnTyp4                NVARCHAR(10),
              @cPH_CtnTyp5                NVARCHAR(10),
              @nPH_CtnCnt1                int,
              @nPH_CtnCnt2                int,
              @nPH_CtnCnt3                int,
              @nPH_CtnCnt4                int,
              @nPH_CtnCnt5                int,
              @nPH_CtnCnt                 int,
              @nPH_CartonCnt              int,
              @nPH_CartonWeight           float,
              @nPH_CartonCube             FLOAT,
              @cPH_CartonGroup            NVARCHAR(10)

      SET @n_RefNo2 = 0                     --(Wan03)
      SET @c_DropID = ''                    --(Wan03)

      Declare @c_CurPickSlipNo nvarchar(10)  --TLTING03
            , @n_CurCartonNo  int 
            , @c_CurLabelNo   nvarchar(20)
            , @c_CurLabelLine nvarchar(5)

      --WL03 START
      DECLARE @c_Option1             NVARCHAR(50) 
            , @c_Option2             NVARCHAR(50) 
            , @c_Option3             NVARCHAR(50) 
            , @c_Option4             NVARCHAR(50) 
            , @c_Option5             NVARCHAR(4000)
            , @c_ReArrangeCartonNo   NVARCHAR(10) = ''
      --WL03 END

      --(YokeBeen01) - START
      DECLARE @c_TriggerName              NVARCHAR(120) 
            , @c_SourceTable              NVARCHAR(60) 
            , @c_Status                   NVARCHAR(10) 
            , @b_ColumnsUpdated           VARBINARY(1000) 

      SET @b_ColumnsUpdated               = COLUMNS_UPDATED() 
      SET @c_TriggerName                  = 'ntrPackHeaderUpdate'
      SET @c_SourceTable                  = 'PACKHEADER'
      --(YokeBeen01) - END

      -- (ChewKP01)
      DECLARE @TempConsoTable TABLE
      (
        RowRef          INT IDENTITY,
        OrderKey        NVARCHAR(10),
        ConsoOrderKEy   NVARCHAR(30) NULL,  --(ChewKP02)
        CompletedFlag   NVARCHAR(1)  NULL
      )

      -- (ChewKP01)
      SET @c_authority_packordlog = ''

      SELECT
         @c_StorerKey   = INSERTED.Storerkey
      FROM   INSERTED, DELETED
      WHERE  INSERTED.Pickslipno = DELETED.Pickslipno
   --   WHERE  INSERTED.Orderkey = DELETED.OrderKey

      EXECUTE dbo.nspGetRight  NULL,
         @c_StorerKey,        -- Storer
         '',                  -- Sku
         'PACKORDLOG',        -- ConfigKey
         @b_success              OUTPUT,
         @c_authority_packordlog OUTPUT,
         @n_err                  OUTPUT,
         @c_errmsg               OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 109652
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(6),ISNULL(@n_err,0))
                          + ': Retrieve of Right (PACKCFMLOG) Failed (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END

		--(LL01)-S
		SET @c_authority_packord2lg = ''

      EXECUTE dbo.nspGetRight  NULL,
         @c_StorerKey,        -- Storer
         '',                  -- Sku
         'PACKORD2LG',        -- ConfigKey
         @b_success              OUTPUT,
         @c_authority_packord2lg OUTPUT,
         @n_err                  OUTPUT,
         @c_errmsg               OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 109652
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(6),ISNULL(@n_err,0))
                          + ': Retrieve of Right (PACKORD2LG) Failed (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' 
                          + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
		--(LL01)-E
   END                                                   --(Wan07)

   --NJOW08
   IF @n_continue=1 or @n_continue=2
      OR @c_ArchiveCopAllowTriggerSP = 'Y' --NJOW09            
   BEGIN
      IF EXISTS (SELECT 1 FROM DELETED d   ----->Put INSERTED if INSERT action
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
                 WHERE  s.configkey = 'PackHeaderTrigger_SP')   -----> Current table trigger storerconfig
      BEGIN
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         SELECT *
         INTO #INSERTED
         FROM INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED

         SELECT *
         INTO #DELETED
         FROM DELETED

         EXECUTE dbo.isp_PackHeaderTrigger_Wrapper ----->wrapper for current table trigger
                   'UPDATE'  -----> @c_Action can be INSERT, UPDATE, DELETE
                 , @b_Success  OUTPUT
                 , @n_Err      OUTPUT
                 , @c_ErrMsg   OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
                  ,@c_errmsg = 'ntrPackHeaderUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  -----> Put current trigger name
         END

         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
            DROP TABLE #INSERTED

         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
            DROP TABLE #DELETED
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF UPDATE(STATUS)
      BEGIN
         SELECT @c_PickSlipNo = ''

         DECLARE C_PckHdrUpd  CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT INSERTED.PickSlipNo, INSERTED.OrderKey, INSERTED.LoadKey, INSERTED.Storerkey, ORDERS.Facility, INSERTED.ConsoOrderKey, INSERTED.PackStatus -- (ChewKP01) -- (ChewKP02)
         FROM   INSERTED
         JOIN   DELETED ON (INSERTED.pickslipno = DELETED.pickslipno)
         LEFT JOIN ORDERS (NOLOCK) ON (INSERTED.Orderkey = ORDERS.Orderkey)
         WHERE  INSERTED.status = '9' AND DELETED.status < '9'
         ORDER BY INSERTED.PickSlipNo, INSERTED.OrderKey

         OPEN C_PckHdrUpd

         FETCH NEXT FROM C_PckHdrUpd INTO @c_PickSlipNo, @c_OrderKey, @c_loadKey, @c_Storerkey, @c_Facility, @c_ConsoOrderKey, @c_PackStatus -- (ChewKP01) -- (ChewKP02)

         WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            --Extended Validation
            --WL01 Start
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SET @b_Success = 0

               SELECT @c_GetOrderkey = Orderkey
               FROM PACKHEADER (NOLOCK) 
               WHERE PickSlipNo = @c_PickSlipNo

               IF @c_GetOrderkey = ''
               BEGIN
                  SET @b_IsConso = 1
                  SET @c_Configkey = 'CFMPackConsoExtValidation'
               END
               ELSE
               BEGIN
                  SET @b_IsConso = 0
                  SET @c_Configkey = 'CFMPackDiscreteExtValidation'
               END
               
               EXEC nspGetRight   
                  @c_Facility          -- facility  
               ,  @c_Storerkey         -- Storerkey  
               ,  NULL                 -- Sku  
               ,  @c_Configkey         -- Configkey  
               ,  @b_Success           OUTPUT   
               ,  @c_GetAuthority      OUTPUT   
               ,  @n_Err               OUTPUT   
               ,  @c_ErrMsg            OUTPUT 
      
               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3, @n_err = 109681, @c_errmsg = 'ntrPackHeaderUpdate ' + ISNULL(RTRIM(@c_errmsg), '')   
               END

               IF @c_GetAuthority <> '' AND @c_GetAuthority <> '0'  --WL02
               BEGIN
                  EXEC isp_Pack_ExtendedValidation
                    @c_Pickslipno          = @c_Pickslipno
                  , @c_PACKValidationRules = @c_GetAuthority
                  , @b_Success             = @b_Success  OUTPUT
                  , @c_ErrMsg              = @c_ErrMsg   OUTPUT
                  , @b_IsConso             = @b_IsConso
                  --select @c_Pickslipno, @c_Configkey, @b_IsConso, @b_Success, @c_ErrMsg
                  IF @b_success <> 1  
                  BEGIN  
                     SELECT @n_continue = 3, @n_err = 109682, @c_errmsg = 'ntrPackHeaderUpdate ' + CHAR(13) + ISNULL(RTRIM(@c_errmsg), '')
                  END
               END --@c_authority
            END --@n_continue
            --WL01 End

            -- Serial no
            --(Wan) - START
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SET @b_Success = 0
               EXECUTE dbo.ispPackConfirmSerialNo
                       @c_PickSlipNo= @c_PickSlipNo
                     , @b_Success   = @b_Success     OUTPUT
                     , @n_Err       = @n_err         OUTPUT
                     , @c_ErrMsg    = @c_errmsg      OUTPUT

               IF @n_err <> 0
                  SET @n_continue= 3
            END

            --(Wan) - END
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               /* Added By Vicky 09 May 2003 for Exceed V5.1 - FBR#11105
               Ignore Update Scanout status when CheckPickB4Pack is turn on' */
               SELECT @b_success = 0
               EXECUTE nspGetRight @c_Facility,  -- facility
                                   @c_Storerkey,    -- Storerkey
                                   NULL,            -- Sku
                                   'CheckPickB4Pack',  -- Configkey
                                   @b_success    OUTPUT,
                                   @c_authority  OUTPUT,
                                   @n_err        OUTPUT,
                                   @c_errmsg     OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @n_err = 109654, @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
               END
               ELSE IF @c_authority <> '1'
               BEGIN
                   --NJOW01
                  SELECT @b_success = 0
                  EXECUTE nspGetRight @c_facility,     -- facility
                                      @c_Storerkey,    -- Storerkey
                                      NULL,            -- Sku
                                      'DisableAutoPickAfterPack',  -- Configkey
                                      @b_success                  OUTPUT,
                                      @c_DisableAutoPickAfterPack OUTPUT,
                                      @n_err                      OUTPUT,
                                      @c_errmsg                   OUTPUT
                  IF @b_success <> 1
                  BEGIN
                    SELECT @n_continue = 3, @n_err = 109655, @c_errmsg = 'ntrPackHeaderUpdate' + RTRIM(@c_errmsg)
                  END

                  -- Added By SHONG
                  -- Date: 15th Sept 2003
                  -- Mandon Singapore Interface
                  -- begin
                  IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
                  BEGIN
                     -- (YokeBeen01) - Start
                     /* IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_Storerkey
                                AND ConfigKey = 'MDMITF' AND sValue = '1'   )
                     BEGIN
                        EXEC ispGenTransmitLog 'MDMORDERS', @c_OrderKey, '', @c_Storerkey, ''
                              , @b_success OUTPUT
                              , @n_err     OUTPUT
                              , @c_errmsg  OUTPUT
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @n_err = 109656
                           SELECT @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
                        End
                     END  -- 'MDMITF' */
                     -- (YokeBeen01) - End

                     --Added By Vicky
                     --Date: 11 Dec 2001
                     --To update scan out date for pickinginfo table and also status in orders, orderdetail, loadplan and pickdetail table

                     IF ( @n_continue = 1 OR @n_continue = 2 ) AND @c_DisableAutoPickAfterPack <> '1'  --NJOW01
                     BEGIN
                        -- check UCCTracking storerconfig
                        -- manually trigger pickdetail update here since TBL UCC do not create pickheader record
                        -- thus, pickinginfo trigger is 'useless'
                        IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) JOIN STORERCONFIG (NOLOCK)
                                   ON PACKHEADER.StorerKey = STORERCONFIG.StorerKey
                                   WHERE PACKHEADER.PickslipNo = @c_PickSlipNo
                                   AND ConfigKey = 'UCCTracking'
                                   AND SValue = '1')
                        BEGIN
                           IF EXISTS(SELECT 1 FROM PACKHEADER (NOLOCK) JOIN STORERCONFIG (NOLOCK)
                                   ON PACKHEADER.StorerKey = STORERCONFIG.StorerKey
                                   WHERE PACKHEADER.PickslipNo = @c_PickSlipNo
                                   AND ConfigKey = 'BackendPickConfirm'
                                   AND SValue = '1')
                           BEGIN
                              -- SHONG04
                              IF EXISTS(SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND Doctype='E')
                              BEGIN
                                 UPDATE PICKDETAIL With (ROWLOCK) -- shong03
                                 SET ShipFlag = 'P',
                                     EditDate = GETDATE(),
                                     EditWho = SUSER_SNAME(),
                                     TrafficCop = NULL
                                 WHERE OrderKey = @c_OrderKey
                                 AND pickslipno = @c_PickSlipNo
                                 AND status < '5'
                                 AND ShipFlag NOT IN ('P','Y')
                              END
                           END
                           ELSE
                           BEGIN
                              UPDATE PICKDETAIL With (ROWLOCK) -- tlting01
                              SET STATUS = '5',
                                  EditDate = GETDATE(),
                                  EditWho = SUSER_SNAME()
                              WHERE OrderKey = @c_OrderKey
                              and pickslipno = @c_PickSlipNo
                              and status < '5'
                           END

                           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                           IF @n_err <> 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109657
                              SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PICKDETAIL. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                           END
                        END
                     END
                  END -- OrderKey <> BLANK

                --247575-IDSUS - Prevent Carton Finalize if having missing UPS Tracking # NJOW04- START
                  IF @n_continue = 1 OR @n_continue = 2
                  BEGIN
                     EXECUTE dbo.nspGetRight  @c_Facility,
                        @c_StorerKey,        -- Storer
                        '',                  -- Sku
                        'CHKUPSDATA',        -- ConfigKey
                        @b_success              OUTPUT,
                        @c_authority_chkupsdata OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 109658
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(6),ISNULL(@n_err,0))
                                         + ': Retrieve of Right (CHKUPSDATA) Failed (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' 
              + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                     END
                     ELSE IF @c_authority_chkupsdata = '1' --NJOW05
                     BEGIN
                         IF ISNULL(@c_ConsoOrderkey,'') <> '' --lci conso order
                           SELECT @c_OrderType = MAX(O.type), @c_upsrtn = MAX(O.M_ISOCntryCode)
                           FROM ORDERDETAIL OD (NOLOCK)
                           JOIN ORDERS O (NOLOCK) ON OD.Orderkey = O.Orderkey
                           WHERE OD.ConsoOrderkey = @c_ConsoOrderkey
                           AND O.Type LIKE 'UPS%'
                        ELSE
                           SELECT @c_OrderType = O.type, @c_upsrtn = O.M_ISOCntryCode
                           FROM ORDERS O (NOLOCK)
                           WHERE O.Orderkey = @c_Orderkey
                           AND O.Type LIKE 'UPS%'

                        IF ISNULL(@c_OrderType,'') <> '' --is UPS order
                        BEGIN
                           SELECT @n_cartonno = MIN(Cartonno)
                           FROM PACKDETAIL PD (NOLOCK)
                           WHERE PD.Pickslipno = @c_Pickslipno
                              AND ISNULL(PD.upc,'') = ''

                           IF ISNULL(@n_cartonno,0) > 0
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @n_err = 109659
                              SELECT @c_errmsg='Cannot Pack Confirm Carton '+ RTRIM(CONVERT(VARCHAR(3),@n_cartonno)) +' of Pickslip# ' +RTRIM(@c_pickslipno)+'. Missing UPS Tracking#.'
                           END

                           IF ISNULL(@c_upsrtn,'') = 'RETURN' AND ISNULL(@c_Orderkey,'') <> ''  --ups return
                           BEGIN
                              SELECT @n_Cartonno = MIN(PCK.Cartonno)
                              FROM (SELECT PD.Cartonno, PD.Labelno, SUM(PD.Qty) AS Qty
                                      FROM PACKDETAIL PD (NOLOCK)
                                     WHERE PD.Pickslipno = @c_Pickslipno
                                     GROUP BY PD.Cartonno, PD.Labelno) AS PCK
                              LEFT JOIN (SELECT Labelno, SUM(Qty) AS Qty
                                           FROM UPSRETURNTRACKNO (NOLOCK)
                                          WHERE ISNULL(RefNo01,'') <> ''
                                            AND Pickslipno = @c_Pickslipno
                                          GROUP BY Labelno) AS RTNTRK ON PCK.Labelno = RTNTRK.Labelno
                              WHERE PCK.Qty <> ISNULL(RTNTRK.Qty,0)

                              IF ISNULL(@n_cartonno,0) > 0
                              BEGIN
                                 SELECT @n_continue = 3
                                 IF @n_err = 109660
                                 BEGIN
                                    SELECT @c_errmsg = @c_errmsg + ' OR Cannot Pack Confirm Carton '+ RTRIM(CONVERT(VARCHAR(3),@n_cartonno)) 
                                                     +' of Pickslip# ' +RTRIM(@c_pickslipno)+'. Missing UPS Return Tracking#.'
                                 END
                                 ELSE
                                 BEGIN
                                    SELECT @n_err = 109661
                                    SELECT @c_errmsg='Cannot Pack Confirm Carton '+ RTRIM(CONVERT(VARCHAR(3),@n_cartonno)) 
                                                    +' of Pickslip# ' +RTRIM(@c_pickslipno)+'. Missing UPS Return Tracking#.'
                                 END
                              END
                           END
                        END
                     END
                  END
                  --247575-IDSUS - Prevent Carton Finalize if having missing UPS Tracking # NJOW04- END

                  IF (@n_continue = 1 OR @n_continue = 2) AND @c_DisableAutoPickAfterPack <> '1'  --NJOW01
                  BEGIN
                     -- (Shong01 ) Aded By SHONG on 04-04-2007
                     IF EXISTS(SELECT 1 FROM PickingInfo (NOLOCK)
                     WHERE PickingInfo.Pickslipno = @c_PickSlipNo
                     AND   ScanOutDate IS NULL)
                     BEGIN
                        UPDATE PickingInfo WITH (ROWLOCK)    -- tlting01
                        SET scanoutdate = getdate()
                        WHERE PickingInfo.Pickslipno = @c_PickSlipNo
                        AND   PickingInfo.ScanOutDate IS NULL

                        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109662
                           SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PICKINGINFO. (ntrPackHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                        END
                     END
                  END
               END -- @c_authority <> '1'
            END

            --NJOW06
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
                  EXECUTE dbo.nspGetRight  @c_Facility,
                  @c_StorerKey,        -- Storer
                  '',                  -- Sku
                  'PackConfirmDelEmptyLine',        -- ConfigKey
                  @b_success                 OUTPUT,
                  @c_PackConfirmDelEmptyLine OUTPUT,
                  @n_err                     OUTPUT,
                  @c_errmsg                  OUTPUT,
                  @c_Option1                 OUTPUT,   --WL03
                  @c_Option2                 OUTPUT,   --WL03
                  @c_Option3                 OUTPUT,   --WL03
                  @c_Option4                 OUTPUT,   --WL03
                  @c_Option5                 OUTPUT    --WL03

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 109663
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(6),ISNULL(@n_err,0))
                                   + ': Retrieve of Right (PackConfirmDelEmptyLine) Failed (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' 
                                   + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
               ELSE IF @c_PackConfirmDelEmptyLine = '1'
               BEGIN
                    IF EXISTS ( SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Pickslipno = @c_PickSlipNo AND (ISNULL(Sku,'') = '' OR Qty = 0) )
                    BEGIN
                       DELETE FROM PACKDETAIL
                        WHERE Pickslipno = @c_PickSlipNo
                          AND (ISNULL(Sku,'') = '' OR Qty = 0)

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109664
                        SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete Failed On Table PACKDETAIL. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                     END
                  END

                  --WL03 START
                    SELECT @c_ReArrangeCartonNo = dbo.fnc_GetParamValueFromString('@c_ReArrangeCartonNo', @c_Option5, @c_ReArrangeCartonNo)    
                    
                    IF @c_ReArrangeCartonNo = 'Y'
                    BEGIN
                       EXEC isp_PackCfmRearrangeCartonNo
                          @c_PickSlipNo   =   @c_PickSlipNo
                        , @b_Success      =   @b_Success      OUTPUT
                        , @n_err          =   @n_err          OUTPUT
                        , @c_errmsg       =   @c_errmsg       OUTPUT
                                              
                       IF @n_err <> 0
                       BEGIN
                          SELECT @n_continue = 3
                          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109888
                          SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Error Executing isp_PackCfmRearrangeCartonNo. (ntrPackHeaderUpdate) '
                                          +'( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                       END
                    END
                    --WL03 END
               END
            END

            -- Added by James on 7/01/2009 (james01)
            -- If configkey turned on, delete those packdetail line with SKU = ''
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @b_success = 0
               EXECUTE nspGetRight NULL,  -- facility
                       @c_Storerkey,    -- Storerkey
                       NULL,            -- Sku
                       'RDTDYNAMICPICK',  -- Configkey
                       @b_success    OUTPUT,
                       @c_authority  OUTPUT,
                       @n_err        OUTPUT,
                       @c_errmsg     OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @n_err = 109665, @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
               END
               ELSE IF @c_authority = '1'
               BEGIN
                  DELETE PACKDETAIL
                  FROM PACKDETAIL WITH (ROWLOCK)
                  JOIN INSERTED ON (PACKDETAIL.Pickslipno = INSERTED.Pickslipno)
                  WHERE PACKDETAIL.StorerKey = @c_Storerkey
                  AND PACKDETAIL.SKU = ''

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109666
                     SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete Failed On Table PACKDETAIL. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END
               END
            END

            ----------------------------------------------------------------------
            --- SOS140791 Capture PackHeader Summary - Carton Information
            ----------------------------------------------------------------------
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               IF RTRIM(@c_StorerKey) = '' OR @c_StorerKey IS NULL
               BEGIN
                  SELECT TOP 1 @c_StorerKey = ORDERS.StorerKey
                    FROM ORDERS WITH (NOLOCK)
                   WHERE OrderKey = @c_OrderKey
               END

               IF NOT EXISTS(SELECT 1 FROM StorerConfig WITH (NOLOCK)
                              WHERE StorerKey = @c_StorerKey
                                AND ConfigKey = 'PackSummB4Packed'
                                AND sValue = '1')
               BEGIN
                  SELECT @c_CartonGroup = CartonGroup
                  FROM   STORER WITH (NOLOCK)
                  WHERE  StorerKey = @c_StorerKey

                  SELECT TOP 1
                         @cDefaultCartonType = CartonType,
                         @n_CartonCube       = [Cube]
                  FROM   CARTONIZATION WITH (NOLOCK)
                  WHERE  CartonizationGroup = @c_CartonGroup
                  ORDER BY UseSequence ASC

                  SELECT @nPackDetCtn = COUNT(DISTINCT CartonNo),
                         @n_PackedCube = @n_CartonCube * COUNT(DISTINCT CartonNo)
                    FROM PACKDETAIL WITH (NOLOCK)
                   WHERE PickSlipNo = @c_PickSlipNo

                  -- Check whether the PackInfo exists? if Yes, then PackInfo will overwrite pack summary
                  IF EXISTS(SELECT 1 FROM PACKINFO WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
                  BEGIN
                     SELECT @cCtnTyp1 = '', @cCtnTyp2 = '', @cCtnTyp3 = '', @cCtnTyp4 = '', @cCtnTyp5 = ''
                     SELECT @nCtnCnt1 = 0, @nCtnCnt2 = 0, @nCtnCnt3 = 0, @nCtnCnt4 = 0, @nCtnCnt5 = 0
                     SET @n_TotalWeight = 0
                     SET @n_TotalCube = 0
                     SET @n_TotalCarton = 0
                     SET @nCtnCnt = 0 --SOS215633

                     DECLARE CUR_PACKINFO_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT CartonType,
                               COUNT(DISTINCT CartonNo),
                               SUM(ISNULL(PACKINFO.Weight,0)),
                               SUM(ISNULL(PACKINFO.[Cube],0))
                          FROM PACKINFO WITH (NOLOCK)
                         WHERE PickSlipNo = @c_PickSlipNo
                           AND (CartonType <> '' AND CartonType IS NOT NULL)
                      GROUP BY CartonType

                     OPEN CUR_PACKINFO_CARTON

                     FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_CartonType, @nCartonCnt, @nCartonWeight, @n_CartonCube
                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SET @nCtnCnt = @nCtnCnt + 1 --SOS215633
                        IF @nCtnCnt = 1
                        BEGIN
                           SET @cCtnTyp1 = @c_CartonType
                           SET @nCtnCnt1 = @nCartonCnt --SOS215633
                        END
                        IF @nCtnCnt = 2
                        BEGIN
                           SET @cCtnTyp2 = @c_CartonType
                           SET @nCtnCnt2 = @nCartonCnt --SOS215633
                        END
                        IF @nCtnCnt = 3
                        BEGIN
                           SET @cCtnTyp3 = @c_CartonType
                           SET @nCtnCnt3 = @nCartonCnt --SOS215633
                        END
                        IF @nCtnCnt = 4
                        BEGIN
                           SET @cCtnTyp4 = @c_CartonType
                           SET @nCtnCnt4 = @nCartonCnt --SOS215633
                        END
                        IF @nCtnCnt = 5
                        BEGIN
                           SET @cCtnTyp5 = @c_CartonType
                           SET @nCtnCnt5 = @nCartonCnt --SOS215633
                        END
                        SET @n_TotalWeight = @n_TotalWeight + @nCartonWeight
                        SET @n_TotalCube   = @n_TotalCube   + @n_CartonCube
                        SET @n_TotalCarton = @n_TotalCarton + @nCartonCnt

                        FETCH NEXT FROM CUR_PACKINFO_CARTON INTO @c_CartonType, @nCartonCnt, @nCartonWeight, @n_CartonCube
                     END
                     CLOSE CUR_PACKINFO_CARTON
                     DEALLOCATE CUR_PACKINFO_CARTON
                  END -- Packinfo exists
                  ELSE
                  BEGIN
                     -- SOS216105 start. Configurable SP to calc carton, cube and weight
                     -- Get pack header carton , cube weight, if there is any
                     SELECT
                        @nCtnCnt1 = ISNULL( CtnCnt1, 0),
                        @nCtnCnt2 = ISNULL( CtnCnt2, 0),
                        @nCtnCnt3 = ISNULL( CtnCnt3, 0),
                        @nCtnCnt4 = ISNULL( CtnCnt4, 0),
                        @nCtnCnt5 = ISNULL( CtnCnt5, 0),
                        @cCtnTyp1 = CtnTyp1,
                        @cCtnTyp2 = CtnTyp2,
                        @cCtnTyp3 = CtnTyp3,
                        @cCtnTyp4 = CtnTyp4,
                        @cCtnTyp5 = CtnTyp5,
                        @n_TotalCube = ISNULL( TotCtnCube, 0),
                        @n_TotalWeight = ISNULL( TotCtnWeight, 0)
                     FROM PackHeader WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickSlipNo

                     SELECT @cSValue = SValue FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND ConfigKey = 'CMSPackingFormula'

                     IF @cSValue <> '' AND @cSValue IS NOT NULL
                     BEGIN
                        -- Get customize stored procedure
                        SELECT
                           @cSP_Carton = Long,
                           @cSP_Cube = Notes,
                           @cSP_Weight = Notes2,
                           @n_Coefficient_carton = CASE WHEN ISNUMERIC(UDF01) = 1 THEN
                                                        CONVERT(float,UDF01) ELSE 1 END,  --NJOW03
                           @n_Coefficient_cube = CASE WHEN ISNUMERIC(UDF02) = 1 THEN
                                                        CONVERT(float,UDF02) ELSE 1 END,  --NJOW03
                           @n_Coefficient_weight = CASE WHEN ISNUMERIC(UDF03) = 1 THEN
                                                        CONVERT(float,UDF03) ELSE 1 END  --NJOW03
                        FROM CodeLkup WITH (NOLOCK)
                        WHERE ListName = 'CMSStrateg'
                           AND Code = @cSValue

                        -- Run carton SP
                        SET @n_err = 0
                        IF @nCtnCnt1 = 0 AND @nCtnCnt2 = 0 AND @nCtnCnt3 = 0 AND @nCtnCnt4 = 0 AND @nCtnCnt5 = 0 AND OBJECT_ID( @cSP_Carton, 'P') IS NOT NULL
                        BEGIN
                           SET @cSQL = 'EXEC ' + @cSP_Carton + ' @cPickSlipNo, @cOrderKey, ' +
                              '@cCtnTyp1 OUTPUT, @cCtnTyp2 OUTPUT, @cCtnTyp3 OUTPUT, @cCtnTyp4 OUTPUT, @cCtnTyp5 OUTPUT, ' +
                              '@nCtnCnt1 OUTPUT, @nCtnCnt2 OUTPUT, @nCtnCnt3 OUTPUT, @nCtnCnt4 OUTPUT, @nCtnCnt5 OUTPUT'
                           SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), ' +
                              '@cCtnTyp1 NVARCHAR( 10) OUTPUT, @cCtnTyp2 NVARCHAR( 10) OUTPUT, @cCtnTyp3 NVARCHAR( 10) OUTPUT, @cCtnTyp4 NVARCHAR( 10) OUTPUT, @cCtnTyp5 NVARCHAR( 10) OUTPUT, ' +
                              '@nCtnCnt1 INT OUTPUT, @nCtnCnt2 INT OUTPUT, @nCtnCnt3 INT OUTPUT, @nCtnCnt4 INT OUTPUT, @nCtnCnt5 INT OUTPUT'
                           EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey,
                              @cCtnTyp1 OUTPUT, @cCtnTyp2 OUTPUT, @cCtnTyp3 OUTPUT, @cCtnTyp4 OUTPUT, @cCtnTyp5 OUTPUT,
                              @nCtnCnt1 OUTPUT, @nCtnCnt2 OUTPUT, @nCtnCnt3 OUTPUT, @nCtnCnt4 OUTPUT, @nCtnCnt5 OUTPUT
                           SET @n_err = @@ERROR

                           --NJOW03
                           SET @nCtnCnt1 = CONVERT(int, ISNULL(@nCtnCnt1,0) * @n_Coefficient_carton)
                           SET @nCtnCnt2 = CONVERT(int, ISNULL(@nCtnCnt2,0) * @n_Coefficient_carton)
                           SET @nCtnCnt3 = CONVERT(int, ISNULL(@nCtnCnt3,0) * @n_Coefficient_carton)
                           SET @nCtnCnt4 = CONVERT(int, ISNULL(@nCtnCnt4,0) * @n_Coefficient_carton)
                           SET @nCtnCnt5 = CONVERT(int, ISNULL(@nCtnCnt5,0) * @n_Coefficient_carton)
                        END

                        -- Run cube SP
                        IF @n_err = 0 AND @n_TotalCube = 0 AND OBJECT_ID( @cSP_Cube, 'P') IS NOT NULL
                        BEGIN
                           SET @cSQL = 'EXEC ' + @cSP_Cube + ' @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT'
                           SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalCube FLOAT OUTPUT'
                           EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey, @n_TotalCube OUTPUT
                           SET @n_err = @@ERROR

                           --NJOW03
                           SET @n_TotalCube = ISNULL(@n_TotalCube,0) * @n_Coefficient_cube
                        END

                        -- Run weight SP
                        IF @n_err = 0 AND @n_TotalWeight = 0 AND OBJECT_ID( @cSP_Weight, 'P') IS NOT NULL
                        BEGIN
                           SET @cSQL = 'EXEC ' + @cSP_Weight + ' @cPickSlipNo, @cOrderKey, @nTotalWeight OUTPUT'
                           SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalWeight FLOAT OUTPUT'
                           EXEC sp_executesql @cSQL, @cParam, @c_PickSlipNo, @c_OrderKey, @n_TotalWeight OUTPUT
                           SET @n_err = @@ERROR

                           --NJOW03
                           SET @n_TotalWeight = ISNULL(@n_TotalWeight,0) * @n_Coefficient_weight
                        END

                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 109667
                           SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Failed exec customize stored procedure. (isp_InsertMBOLDetail_ung)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                        END
                     END
                     -- SOS216105 end. Configurable SP to calc carton, cube and weight
                     --(Wan01) - START
                     ELSE
                     BEGIN
                        IF @n_TotalWeight IS NULL OR @n_TotalWeight = 0
                        BEGIN
                           SELECT @n_TotalWeight = SUM(SKU.STDNETWGT * PACKDETAIL.Qty)
                           FROM   PACKDETAIL WITH (NOLOCK)
                           JOIN   SKU WITH (NOLOCK) ON PACKDETAIL.StorerKey = SKU.StorerKey AND PACKDETAIL.SKU = SKU.SKU
                           WHERE  PACKDETAIL.PickSlipNo = @c_PickSlipNo
                        END
                        IF (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5) = 0
                        BEGIN
                           SELECT @cCtnTyp1 = @cDefaultCartonType,
                           @nCtnCnt1 = @nPackDetCtn,
                           @n_TotalCube = @n_PackedCube
                        END
                     END
                     --(Wan01) - END
                  END

                  IF (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5) <> @nPackDetCtn
                  BEGIN
                     IF @cCtnTyp1 = @cDefaultCartonType
                     BEGIN
                        SET @nCtnCnt1 = @nPackDetCtn - (@nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5)
                     END
                     IF @cCtnTyp2 = @cDefaultCartonType
                     BEGIN
                        SET @nCtnCnt2 = @nPackDetCtn - (@nCtnCnt1 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5)
                     END
                     IF @cCtnTyp3 = @cDefaultCartonType
                     BEGIN
                        SET @nCtnCnt3 = @nPackDetCtn - (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt4 + @nCtnCnt5) --SOS215633
                     END
                     IF @cCtnTyp4 = @cDefaultCartonType
                     BEGIN
                        SET @nCtnCnt4 = @nPackDetCtn - (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt5)
                     END
                     IF @cCtnTyp5 = @cDefaultCartonType
                     BEGIN
                        SET @nCtnCnt5 = @nPackDetCtn - (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4) --SOS215633
                     END
                  END

                  UPDATE PACKHEADER
                  SET CtnCnt1 = @nCtnCnt1,
                      CtnCnt2 = @nCtnCnt2,
                      CtnCnt3 = @nCtnCnt3,
                      CtnCnt4 = @nCtnCnt4,
                      CtnCnt5 = @nCtnCnt5,
                      CtnTyp1 = @cCtnTyp1,
                      CtnTyp2 = @cCtnTyp2,
                      CtnTyp3 = @cCtnTyp3,
                      CtnTyp4 = @cCtnTyp4,
                      CtnTyp5 = @cCtnTyp5,
                      TotCtnWeight = @n_TotalWeight,
                      TotCtnCube   = @n_TotalCube,
                      CartonGroup  = @c_CartonGroup,
                      -- Added By SHONG ON 31-Dec-2011
                      -- Update total cartons count
                      TTLCNTS      = CASE WHEN TTLCNTS > 0 THEN TTLCNTS
                                          WHEN (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5) > 0
                                             THEN (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5)
                                          WHEN @nPackDetCtn > 0 THEN @nPackDetCtn
                                     END,
                      EditDate = GETDATE(), --tlting
                      EditWho = SUSER_SNAME()
                  WHERE PICKSLIPNO = @c_PickSlipNo
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109668
                     SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PACKHEADER. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END

                  -- SHONG02 Performance Tuning
                  SET @cPH_CtnTyp1       = ''
                  SET @cPH_CtnTyp2       = ''
                  SET @cPH_CtnTyp3       = ''
                  SET @cPH_CtnTyp4       = ''
                  SET @cPH_CtnTyp5       = ''
                  SET @nPH_CtnCnt1       = 0
                  SET @nPH_CtnCnt2       = 0
                  SET @nPH_CtnCnt3       = 0
                  SET @nPH_CtnCnt4       = 0
                  SET @nPH_CtnCnt5       = 0
                  SET @nPH_CtnCnt        = 0
                  SET @nPH_CartonCnt     = 0
                  SET @nPH_CartonWeight  = 0
                  SET @cPH_CartonGroup   = ''

                  SELECT @cPH_CartonGroup = MAX(PACKHEADER.CartonGroup),
                         @nPH_CtnCnt1 = SUM(ISNULL(CtnCnt1,0)),
                         @nPH_CtnCnt2 = SUM(ISNULL(CtnCnt2,0)),
                         @nPH_CtnCnt3 = SUM(ISNULL(CtnCnt3,0)),
                         @nPH_CtnCnt4 = SUM(ISNULL(CtnCnt4,0)),
                         @nPH_CtnCnt5 = SUM(ISNULL(CtnCnt5,0)),
                         @nPH_CartonWeight = SUM(ISNULL(TotCtnWeight,0)),
                         @nPH_CartonCube   = SUM(ISNULL(TotCtnCube,0)),
                         @cPH_CtnTyp1 = MAX(CtnTyp1),
                         @cPH_CtnTyp2 = MAX(CtnTyp2),
                         @cPH_CtnTyp3 = MAX(CtnTyp3),
                         @cPH_CtnTyp4 = MAX(CtnTyp4),
                         @cPH_CtnTyp5 = MAX(CtnTyp5)
                    FROM PACKHEADER WITH (NOLOCK)
                   WHERE LoadKey = @c_LoadKey

                  UPDATE LOADPLAN WITH (ROWLOCK)
                  SET CtnCnt1 = @nPH_CtnCnt1,
                      CtnCnt2 = @nPH_CtnCnt2,
                      CtnCnt3 = @nPH_CtnCnt3,
                      CtnCnt4 = @nPH_CtnCnt4,
                      CtnCnt5 = @nPH_CtnCnt5,
                      CtnTyp1 = @cPH_CtnTyp1,
                      CtnTyp2 = @cPH_CtnTyp2,
                      CtnTyp3 = @cPH_CtnTyp3,
                      CtnTyp4 = @cPH_CtnTyp4,
                      CtnTyp5 = @cPH_CtnTyp5,
                      TotCtnWeight = @nPH_CartonWeight,
                      TotCtnCube   = @nPH_CartonCube,
                      CartonGroup  = @cPH_CartonGroup,
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
                  WHERE LOADPLAN.LoadKey = @c_LoadKey
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109669
                     SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table LOADPLAN. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END

                  -- Adding Back the missing part of the previous version
                  IF (@nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5) = 0
                  BEGIN
                     SELECT @b_success = 0
                     EXECUTE nspGetRight NULL,            -- facility
                                         @c_Storerkey,    -- Storerkey
                                         NULL,            -- Sku
                                         'AutoPackConfirm',  -- Configkey
                                         @b_success    OUTPUT,
                                         @c_authority  OUTPUT,
                                         @n_err        OUTPUT,
                                         @c_errmsg     OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3, @n_err = 109670, @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
                     END
                     ELSE IF @c_authority = '1'
                     BEGIN
                        IF EXISTS (SELECT 1 FROM PackHeader WITH (NOLOCK)
                                   WHERE Status = '9'
                                   AND Orderkey = @c_orderkey
                                   HAVING COUNT(PickSlipNo) > 1)
                        BEGIN
                           SELECT @nCtnCnt1 = COUNT(DISTINCT PD.LabelNo)
                           FROM PACKHEADER PH (NOLOCK)
                           JOIN PACKDETAIL PD (NOLOCK) ON (PH.pickslipno = PD.pickslipno)
                           WHERE PH.Status = '9'
                           AND PH.Orderkey = @c_orderkey
                        END
                        -- SOS# 213276 (End)
                        ELSE
                        BEGIN
                           SELECT @nCtnCnt1 = COUNT(DISTINCT PD.Cartonno)
                           FROM PACKHEADER PH (NOLOCK)
                           JOIN PACKDETAIL PD (NOLOCK) ON (PH.pickslipno = PD.pickslipno)
                           WHERE PH.Status = '9'
                           AND PH.Orderkey = @c_orderkey
                           AND PH.Pickslipno = @c_PickSlipNo
                        END
                     END
                  END

                  IF ISNULL(RTRIM(@c_OrderKey),'') <> ''
                  BEGIN
                     -- SOS216105 start. Configurable SP to calc carton, cube and weight
                     -- Update carton type, count if user not key-in own value

                     IF EXISTS ( SELECT 1 FROM  MBOLDetail with (NOLOCK)
                    WHERE OrderKey = @c_OrderKey
                                    AND CtnCnt1 = 0   AND CtnCnt2 = 0   AND CtnCnt3 = 0
                                    AND CtnCnt4 = 0  AND CtnCnt5 = 0  AND TotalCartons = 0   )
                         AND ( @nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5 ) > 0
                     BEGIN
                        UPDATE MBOLDetail with (ROWLOCK)
                        SET
                           CtnCnt1 = @nCtnCnt1,
                           CtnCnt2 = @nCtnCnt2,
                           CtnCnt3 = @nCtnCnt3,
                           CtnCnt4 = @nCtnCnt4,
                           CtnCnt5 = @nCtnCnt5,
                           TotalCartons = @nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5,
                           EditDate = GETDATE(),   --tlting
                           EditWho = SUSER_SNAME()
                        WHERE OrderKey = @c_OrderKey  -- if discrete pick list, update MBOLDetail
                           AND CtnCnt1 = 0
                           AND CtnCnt2 = 0
                           AND CtnCnt3 = 0
                           AND CtnCnt4 = 0
                           AND CtnCnt5 = 0
                           AND TotalCartons = 0
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109671
                           SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PACKHEADER. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                        END
                     END

                     IF EXISTS ( SELECT 1 FROM  MBOLDetail WITH (NOLOCK)
                                 WHERE OrderKey = @c_OrderKey  AND [Cube] = 0 )
                        AND @n_TotalCube > 0
                     BEGIN
                        -- Update cube if user not key-in own value
                        UPDATE MBOLDetail WITH (ROWLOCK)
                           SET [Cube] = @n_TotalCube,
                               EditDate = GETDATE(),    -- tlting
                               EditWho = SUSER_SNAME()
                         WHERE OrderKey = @c_OrderKey AND [Cube] = 0

                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109672
                           SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PACKHEADER. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                        END
                     END

                     -- Update weight if user not key-in own value
                     IF EXISTS ( SELECT 1 FROM  MBOLDetail WITH (NOLOCK)
                                  WHERE OrderKey = @c_OrderKey  AND [Weight] = 0 )
                                    AND @n_TotalWeight > 0
                     BEGIN
                        UPDATE MBOLDetail with (ROWLOCK)
                           SET Weight = @n_TotalWeight,
                               EditDate = GETDATE(),    -- tlting
                               EditWho = SUSER_SNAME()
                         WHERE OrderKey = @c_OrderKey AND Weight = 0

                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109673
                           SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PACKHEADER. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                        END
                     END
                     -- SOS216105 end. Configurable SP to calc carton, cube and weight
                  END -- IF ISNULL(RTRIM(@c_OrderKey),'') <> ''
                  ELSE
                  BEGIN
                     DECLARE CUR_MBOL_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT DISTINCT ORDERKEY
                       FROM RefKeyLookUp WITH (NOLOCK)
                      WHERE PickSlipNo = @c_PickSlipNo

                     OPEN CUR_MBOL_ORDERS
                     FETCH NEXT FROM CUR_MBOL_ORDERS INTO @c_COrderKey

                     WHILE @@FETCH_STATUS <> -1
                     BEGIN
                        SELECT @n_TotalCarton = COUNT(Distinct LabelNo)
                        FROM PACKDETAIL WITH (NOLOCK)
                        WHERE PACKDETAIL.PickSlipNo IN (SELECT DISTINCT PickSlipNo
                                                        FROM RefKeyLookUp WITH (NOLOCK)
                                                        WHERE RefKeyLookUp.Orderkey = @c_COrderKey)

                        UPDATE MBOLDetail with (ROWLOCK)
                           SET TotalCartons = @n_TotalCarton,
                               Editdate = Getdate(),
                               TrafficCop = NULL
                         WHERE OrderKey = @c_COrderKey
                           AND (TotalCartons = 0 OR TotalCartons IS NULL)

                        FETCH NEXT FROM CUR_MBOL_ORDERS INTO @c_COrderKey
                     END
                     CLOSE CUR_MBOL_ORDERS
                     DEALLOCATE CUR_MBOL_ORDERS
                  END
               END -- StorerConfig 'PackSummB4Packed' Not turn On.
            END
            ----------------------------------------------------------------------
            -- END of SOS140791
            ----------------------------------------------------------------------

            /* (Wan02) - (START) */
            IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               SET  @b_success = 0
               EXECUTE nspGetRight @c_Facility                -- facility
                                 , @c_Storerkey               -- Storerkey
                                 , NULL                       -- Sku
                                 , 'ShortPickAutoClosePack'   -- Configkey
                                 , @b_success    OUTPUT
                                 , @c_authority  OUTPUT
                                 , @n_err        OUTPUT
                                 , @c_errmsg     OUTPUT

  IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @n_err = 109674, @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
               END
               ELSE IF @c_authority = '1'
               BEGIN
                  IF ISNULL(RTRIM(@c_Orderkey),'') <> ''
                  BEGIN
                     SELECT @n_TotalCarton = COUNT (DISTINCT CartonNo)
                     FROM PACKDETAIL WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickSlipNo

                     UPDATE MBOLDETAIL WITH (ROWLOCK)
                     SET TotalCartons = @n_TotalCarton
                        ,EditDate = GetDate()
                        ,EditWho = SUser_Name()
                     WHERE MBOLDETAIL.Orderkey = @c_Orderkey
                  END
               END
            END
            /* (Wan02) - (END)   */

            /* (Wan03) - (START) */
            IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               SET  @b_success = 0
               EXECUTE nspGetRight @c_Facility                -- facility
                                 , @c_Storerkey               -- Storerkey
                                 , NULL                       -- Sku
                                 , 'UpdCtnXLoad'              -- Configkey
                                 , @b_success    OUTPUT
                                 , @c_authority  OUTPUT
                                 , @n_err        OUTPUT
                                 , @c_errmsg     OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @n_err = 109675, @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
               END
               ELSE IF @c_authority = '1'
               BEGIN
                  --(Wan06) - START
                  IF EXISTS ( SELECT 1
                              FROM PICKHEADER PIH WITH (NOLOCK)
                              JOIN ORDERS     OH  WITH (NOLOCK) ON (PIH.Orderkey = OH.Orderkey)
                              LEFT JOIN PACKHEADER PAH WITH (NOLOCK) ON (PIH.PickHeaderKey = PAH.PickSlipNo)
                              WHERE OH.Loadkey = @c_Loadkey
                              GROUP BY OH.Loadkey
                              HAVING COUNT(PIH.PickheaderKey) = SUM(CASE WHEN PAH.Status = '9' THEN 1 ELSE 0 END)
                            )
                  BEGIN
                     SET @n_RefNo2 = 0

                     DECLARE CUR_CTN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT DropID = ISNULL(RTRIM(PACKDETAIL.DropID),'')
                     FROM PACKHEADER WITH (NOLOCK)
                     JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickslipNo)
                     LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'SIZESEQ')
                                                         AND(RTRIM(SUBSTRING(PACKDETAIL.Sku,10,LEN(PACKDETAIL.Sku)- 9)) = CL.Code)
                     WHERE PACKHEADER.LoadKey = @c_Loadkey
                     GROUP BY ISNULL(RTRIM(PACKDETAIL.DropID),'')
                     ORDER BY MIN(SUBSTRING(PACKDETAIL.Sku,1,9)
                           +  RIGHT('0000000000' + ISNULL(CL.Short,''), 11)
                           +  CONVERT(NCHAR(20),ISNULL(RTRIM(PACKDETAIL.DropID),''))
                           +  CONVERT(NVARCHAR(25),PACKDETAIL.AddDate,121))

                     OPEN CUR_CTN

                     FETCH NEXT FROM CUR_CTN INTO @c_DropID

                     WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
                     BEGIN
                        SET @n_RefNo2 = @n_RefNo2 + 1

                        --TLTING03
                        SET @c_CurPickSlipNo = ''
                        SET @n_CurCartonNo = 0
                        SET @c_CurLabelNo = '' 
                        SET @c_CurLabelLine = ''
                         
                   DECLARE CUR_PDetUpd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT PACKDETAIL.PickSlipNo, PACKDETAIL.CartonNo, PACKDETAIL.LabelNo, PACKDETAIL.LabelLine
                        FROM PACKHEADER WITH (NOLOCK)
                        JOIN PACKDETAIL with (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickslipNo)   --tlting04
                        WHERE PACKHEADER.LoadKey = @c_Loadkey
                        AND   PACKDETAIL.DropID  = @c_DropID

                        OPEN CUR_PDetUpd

                        FETCH NEXT FROM CUR_PDetUpd INTO @c_CurPickSlipNo, @n_CurCartonNo, @c_CurLabelNo, @c_CurLabelLine

                        WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 OR @n_continue = 2)
                        BEGIN
                           UPDATE PACKDETAIL WITH (ROWLOCK)
                           SET RefNo2 = CONVERT(VARCHAR(10), @n_RefNo2)
                              ,EditDate = GETDATE()
                              ,EditWho  = SUSER_NAME()
                              ,ArchiveCop = NULL
                           FROM  PACKDETAIL  
                           WHERE PickSlipNo = @c_CurPickSlipNo
                           AND   CartonNo = @n_CurCartonNo
                           AND   LabelNo  = @c_CurLabelNo
                           AND   LabelLine =  @c_CurLabelLine

                           FETCH NEXT FROM CUR_PDetUpd INTO @c_CurPickSlipNo, @n_CurCartonNo, @c_CurLabelNo, @c_CurLabelLine
                        END
                        CLOSE CUR_PDetUpd
                        DEALLOCATE CUR_PDetUpd

                        FETCH NEXT FROM CUR_CTN INTO @c_DropID
                     END
                     CLOSE CUR_CTN
                     DEALLOCATE CUR_CTN
                  END
               END
               --(Wan06) - END
            END
            /* (Wan03) - (END)   */

            --(Wan) - END
            -- (MC01) - E

            -- (YokeBeen01) - Start
            /* IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               SET  @b_success = 0
               SET  @c_authority = ''
               EXECUTE dbo.nspGetRight @c_Facility
                                     , @c_StorerKey  -- Storer
                                     , ''            -- Sku
                                     , 'PACKEDLOG'   -- ConfigKey
                                     , @b_success    OUTPUT
                                     , @c_authority  OUTPUT
                                     , @n_err        OUTPUT
                                     , @c_errmsg     OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @n_err = 109676, @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
               END

               IF @c_authority = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'PACKEDLOG', @c_Orderkey, '', @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
            END --IF (@n_continue = 1 OR @n_continue = 2) */
            -- (YokeBeen01) - End
            -- (MC01) - E

            -- (YokeBeen01) - Start
            /*--NJOW07 S
            IF (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               SET  @b_success = 0
               SET  @c_authority = ''
               EXECUTE dbo.nspGetRight @c_Facility
                                     , @c_StorerKey  -- Storer
                                     , ''            -- Sku
                                     , 'PACKED2LOG'   -- ConfigKey
                                     , @b_success    OUTPUT
                                     , @c_authority  OUTPUT
                              , @n_err        OUTPUT
                                     , @c_errmsg     OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3, @n_err = 109677, @c_errmsg = 'ntrPackHeaderUpdate' + ISNULL(RTRIM(@c_errmsg), '')
               END

               IF @c_authority = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'PACKED2LOG', @c_Orderkey, '', @c_StorerKey, ''
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
            END --IF (@n_continue = 1 OR @n_continue = 2)
            --NJOW07 E */
            -- (YokeBeen01) - End

            ----------------------------------------------------------------------
            -- PackOrdLog - Start (ChewKP01)
            ----------------------------------------------------------------------
            IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_authority_packordlog,'') = '1'
            BEGIN
               -- FOR LCI Project
               -- Insert PackOrdLog on When All ConsoOrderKey in that Order had been packed.
               INSERT INTO @TempConsoTable ( OD.OrderKey, OD.ConsoOrderKey )
               SELECT DISTINCT OD.OrderKey , OD.ConsoOrderKey
                 FROM dbo.OrderDetail OD WITH (NOLOCK)
                 JOIN dbo.RefKeyLookUp RKL WITH (NOLOCK) ON RKL.OrderKey = OD.OrderKey AND RKL.OrderLineNumber = OD.OrderLineNumber
                WHERE rkl.Pickslipno = @c_PickSlipNo


               -- Update ConsoOrder Packing Status
               DECLARE CUR_CONSOStatus CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT DISTINCT ConsoOrderKey
                 FROM @TempConsoTable

               OPEN CUR_CONSOStatus
               FETCH NEXT FROM CUR_CONSOStatus INTO @c_TSConsoOrderKey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                             WHERE ConsoOrderKey = @c_TSConsoOrderKey   -- (ChewKP02)
                             AND Status = '9')
                  BEGIN
                     UPDATE @TempConsoTable
                        SET CompletedFlag = '1'
                      WHERE ConsoOrderKey =  @c_TSConsoOrderKey
                  END
                  ELSE
                  BEGIN
                     UPDATE @TempConsoTable
                        SET CompletedFlag = '0'
                      WHERE ConsoOrderKey =  @c_TSConsoOrderKey
                  END

                  FETCH NEXT FROM CUR_CONSOStatus INTO @c_TSConsoOrderKey
               END
               CLOSE CUR_CONSOStatus
               DEALLOCATE CUR_CONSOStatus

               -- Generate PackOrdLog when all CompletedFlag in 1 Order is = '1'
               DECLARE CUR_GENPACKORDLOG CURSOR LOCAL READ_ONLY FAST_FORWARD FOR

               SELECT DISTINCT OrderKey
               FROM @TempConsoTable

               OPEN CUR_GENPACKORDLOG
               FETCH NEXT FROM CUR_GENPACKORDLOG INTO @c_TSOrderKey
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM @TempConsoTable
                                  WHERE CompletedFlag = '0'
                                    AND OrderKey = @c_TSOrderKey)
                  BEGIN
                     IF NOT EXISTS (SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK)
                                     WHERE TableName = 'PACKORDLOG'
                                       AND Key1 = @c_TSOrderKey )
                     BEGIN
                        EXEC dbo.ispGenTransmitLog3 'PACKORDLOG', @c_TSOrderKey, '', @c_StorerKey, ''
                                          , @b_success OUTPUT
                              , @n_err OUTPUT
                                          , @c_errmsg OUTPUT
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                        END
                     END
							--(LL01) - S
							IF ISNULL(@c_authority_packord2lg,'') = '1'
							BEGIN
								IF NOT EXISTS (SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK)
													 WHERE TableName = 'PACKORD2LG'
														AND Key1 = @c_TSOrderKey )
								BEGIN
									EXEC dbo.ispGenTransmitLog3 'PACKORD2LG', @c_TSOrderKey, '', @c_StorerKey, ''
															, @b_success OUTPUT
															, @n_err OUTPUT
															, @c_errmsg OUTPUT
									IF @b_success <> 1
									BEGIN
										SELECT @n_continue = 3
									END
								END
							END
							--(LL01) - E
                  END
                  FETCH NEXT FROM CUR_GENPACKORDLOG INTO @c_TSOrderKey
               END
               CLOSE CUR_GENPACKORDLOG
               DEALLOCATE CUR_GENPACKORDLOG
            END
            ----------------------------------------------------------------------
            -- PackOrdLog - End (ChewKP01)
            ----------------------------------------------------------------------
            FETCH NEXT FROM C_PckHdrUpd INTO @c_PickSlipNo, @c_OrderKey, @c_loadKey, @c_Storerkey, @c_Facility, @c_ConsoOrderKey, @c_PackStatus -- (ChewKP01) -- (ChewKP02)
         END -- While Pickslip#
         CLOSE C_PckHdrUpd
         DEALLOCATE C_PckHdrUpd

         -- Undo pack confirm
         IF EXISTS( SELECT TOP 1 1
                      FROM INSERTED
                      JOIN DELETED ON (INSERTED.PickSlipNo = DELETED.PickSlipNo)
                     WHERE INSERTED.Status = '0'
                       AND DELETED.Status = '9')
         BEGIN
            DECLARE @curPH CURSOR
            SET @curPH = CURSOR FOR

            SELECT INSERTED.PickSlipNo
              FROM INSERTED
              JOIN DELETED ON (INSERTED.PickSlipNo = DELETED.PickSlipNo)
             WHERE INSERTED.Status = '0'
               AND DELETED.Status = '9'
             ORDER BY INSERTED.PickSlipNo

            OPEN @curPH
            FETCH NEXT FROM @curPH INTO @c_PickSlipNo
            WHILE @@FETCH_STATUS = 0 AND (@n_continue = 1 OR @n_continue = 2)
            BEGIN
               UPDATE PackHeader SET
                      PackStatus = 'REPACK',
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
                WHERE PickSlipNo = @c_PickSlipNo

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109653
                  SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PACKHEADER. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                  BREAK
               END
               FETCH NEXT FROM @curPH INTO @c_PickSlipNo
            END
         END
      END -- If Update(Status)
      ELSE IF UPDATE(TotCtnWeight) OR UPDATE(TotCtnCube) OR
              UPDATE(CtnCnt1) OR
              UPDATE(CtnCnt2) OR
              UPDATE(CtnCnt3) OR
              UPDATE(CtnCnt4) OR
              UPDATE(CtnCnt5) OR
              UPDATE(CtnTyp1) OR
              UPDATE(CtnTyp2) OR
              UPDATE(CtnTyp3) OR
              UPDATE(CtnTyp4) OR
              UPDATE(CtnTyp5)
      BEGIN
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            -- SHONG02 Performance Tuning
            SET @cPH_CtnTyp1       = ''
            SET @cPH_CtnTyp2       = ''
            SET @cPH_CtnTyp3       = ''
            SET @cPH_CtnTyp4       = ''
            SET @cPH_CtnTyp5       = ''
            SET @nPH_CtnCnt1  = 0
            SET @nPH_CtnCnt2       = 0
        SET @nPH_CtnCnt3       = 0
            SET @nPH_CtnCnt4       = 0
            SET @nPH_CtnCnt5       = 0
            SET @nPH_CtnCnt        = 0
            SET @nPH_CartonCnt     = 0
            SET @nPH_CartonWeight  = 0
            SET @cPH_CartonGroup   = ''

            DECLARE C_PckHdrUpd  CURSOR FAST_FORWARD READ_ONLY FOR
            SELECT INSERTED.LoadKey
            FROM   INSERTED

            OPEN C_PckHdrUpd
            FETCH NEXT FROM C_PckHdrUpd INTO @c_loadkey
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @cPH_CartonGroup = MAX(PACKHEADER.CartonGroup),
                      @nPH_CtnCnt1 = SUM(ISNULL(CtnCnt1,0)),
                      @nPH_CtnCnt2 = SUM(ISNULL(CtnCnt2,0)),
                      @nPH_CtnCnt3 = SUM(ISNULL(CtnCnt3,0)),
                      @nPH_CtnCnt4 = SUM(ISNULL(CtnCnt4,0)),
                      @nPH_CtnCnt5 = SUM(ISNULL(CtnCnt5,0)),
                      @nPH_CartonWeight = SUM(ISNULL(TotCtnWeight,0)),
                      @nPH_CartonCube   = SUM(ISNULL(TotCtnCube,0)),
                      @cPH_CtnTyp1 = MAX(CtnTyp1),
                      @cPH_CtnTyp2 = MAX(CtnTyp2),
                      @cPH_CtnTyp3 = MAX(CtnTyp3),
                      @cPH_CtnTyp4 = MAX(CtnTyp4),
                      @cPH_CtnTyp5 = MAX(CtnTyp5)
                 FROM PACKHEADER WITH (NOLOCK)
                WHERE LoadKey = @c_LoadKey

               UPDATE LOADPLAN WITH (ROWLOCK)
               SET CtnCnt1 = @nPH_CtnCnt1,
                   CtnCnt2 = @nPH_CtnCnt2,
                   CtnCnt3 = @nPH_CtnCnt3,
                   CtnCnt4 = @nPH_CtnCnt4,
                   CtnCnt5 = @nPH_CtnCnt5,
                   CtnTyp1 = @cPH_CtnTyp1,
                   CtnTyp2 = @cPH_CtnTyp2,
                   CtnTyp3 = @cPH_CtnTyp3,
                   CtnTyp4 = @cPH_CtnTyp4,
                   CtnTyp5 = @cPH_CtnTyp5,
                   TotCtnWeight = @nPH_CartonWeight,
                   TotCtnCube   = @nPH_CartonCube,
                   CartonGroup  = @cPH_CartonGroup,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()
               WHERE LOADPLAN.LoadKey = @c_LoadKey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109678
                  SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table LOADPLAN. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END

               FETCH NEXT FROM C_PckHdrUpd INTO @c_loadkey
            END -- While
            CLOSE C_PckHdrUpd
            DEALLOCATE C_PckHdrUpd
         END -- Continue = 1
      END -- IF UPDATE(TotCtnWeight)
   END -- @n_continue = 1 OR @n_continue = 2

   --(Wan05) - START
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS ( SELECT 1 FROM INSERTED, DELETED
                   WHERE INSERTED.Pickslipno = DELETED.Pickslipno
                     AND INSERTED.[status] = '9'
                     AND DELETED.[status]  < '9' )
                     AND UPDATE(Status)
      BEGIN
         SELECT @c_PickSlipNo = PickSlipNo
         FROM INSERTED

         SET @b_Success = 0
         EXECUTE dbo.ispPostPackConfirmWrapper
                 @c_PickSlipNo= @c_PickSlipNo
               , @b_Success   = @b_Success     OUTPUT
               , @n_Err       = @n_err         OUTPUT
               , @c_ErrMsg    = @c_errmsg      OUTPUT
               , @b_debug     = 0

         IF @n_err <> 0
         BEGIN
            SET @n_continue= 3
            SET @n_err = 109679
            SET @c_errmsg = CONVERT(char(5),@n_err)
            SET @c_errmsg = 'NSQL'+CONVERT(char(6), @n_err)+ ': Execute ispPostPackConfirmWrapper Failed. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' 
                          + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
         END
      END
   END
   --(Wan05) - END

   IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      -- Added by YokeBeen on 19-Sept-2003 for EditDate updating - Start
      UPDATE PACKHEADER WITH (ROWLOCK)
         SET EditDate = GETDATE() ,
             EditWho = SUser_SName(),
             ArchiveCop = PACKHEADER.ArchiveCop      --tlting02
        FROM PACKHEADER
        JOIN INSERTED ON (PACKHEADER.Pickslipno = INSERTED.Pickslipno)
       WHERE PACKHEADER.[STATUS] = '9'               --tlting02
      -- Added by YokeBeen on 19-Sept-2003 for EditDate updating - End

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 109680
         SELECT @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Update Failed On Table PACKHEADER. (ntrPackHeaderUpdate) ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      END
   END

   IF @n_continue = 1 OR @n_continue = 2 -- (Trigger Point)
   BEGIN 
   /********************************************************/
   /* Interface Trigger Points Calling Process - (Start)   */
   /********************************************************/
   -- (YokeBeen01) - Start
      DECLARE Cur_PackHeader_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      -- Extract values for required variables
       SELECT DISTINCT INSERTED.PickSlipNo
         FROM INSERTED 
         JOIN ITFTriggerConfig WITH (NOLOCK) ON ( ITFTriggerConfig.StorerKey = INSERTED.StorerKey )
        WHERE ITFTriggerConfig.SourceTable = @c_SourceTable
          AND ITFTriggerConfig.sValue      = '1'
       UNION 
       SELECT DISTINCT INSERTED.PickSlipNo 
         FROM INSERTED   
         JOIN ITFTriggerConfig WITH (NOLOCK) ON ( ITFTriggerConfig.StorerKey = 'ALL' )
         JOIN StorerConfig WITH (NOLOCK) ON ( StorerConfig.StorerKey = INSERTED.StorerKey AND 
                                              StorerConfig.ConfigKey = ITFTriggerConfig.ConfigKey AND 
                                              StorerConfig.SValue = '1' )
        WHERE ITFTriggerConfig.SourceTable = @c_SourceTable 
          AND ITFTriggerConfig.sValue      = '1' 

      OPEN Cur_PackHeader_TriggerPoints  
      FETCH NEXT FROM Cur_PackHeader_TriggerPoints INTO @c_PickSlipNo 

      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         -- Execute SP - isp_ITF_ntrPackHeader
         EXECUTE dbo.isp_ITF_ntrPackHeader
                  @c_TriggerName    = @c_TriggerName
                , @c_SourceTable    = @c_SourceTable
                , @c_PickSlipNo     = @c_PickSlipNo
                , @b_ColumnsUpdated = @b_ColumnsUpdated 
                , @b_Success        = @b_Success OUTPUT
                , @n_err            = @n_err     OUTPUT
                , @c_errmsg         = @c_errmsg  OUTPUT

         FETCH NEXT FROM Cur_PackHeader_TriggerPoints INTO @c_PickSlipNo
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_PackHeader_TriggerPoints
      DEALLOCATE Cur_PackHeader_TriggerPoints
   -- (YokeBeen01) - End
   END -- IF @n_continue = 1 OR @n_continue = 2 -- (Trigger Point)
   /********************************************************/
   /* Interface Trigger Points Calling Process - (End)     */
   /********************************************************/

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPackHeaderUpdate'
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