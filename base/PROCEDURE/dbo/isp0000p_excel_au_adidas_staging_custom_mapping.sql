SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store Procedure:  isp0000P_EXCEL_AU_ADIDAS_Staging_Custom_Mapping     */
/* CreatiON Date:  18-Dec-2012                                           */
/* Copyright: IDS                                                        */
/* Written by:  CSCHONG                                                  */
/*                                                                       */
/* Purpose:  ExcelLoader                                                 */
/*                                                                       */
/* Input Parameters:  @iFileID  - (FileKey of the program)               */
/*                    @vcUserName    - (Login Name)                      */
/*                    @cType    - 0_check,1_import                       */
/*                                                                       */
/*                                                                       */
/* Output Parameters:  NONe                                              */
/*                                                                       */
/* Return Status:  NONe                                                  */
/*                                                                       */
/* Usage: ExcelLoader for Receipt                                        */
/*                                                                       */
/*                                                                       */
/*                                                                       */
/*                                                                       */
/* Local Variables:                                                      */
/*                                                                       */
/* Called By: ExcelLoader Program                                        */
/*                                                                       */
/* PVCS VersiON:                                                         */
/*                                                                       */
/* VersiON:                                                              */
/*                                                                       */
/* Data ModificatiONs:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Purposes                                       */
/* 10-Jan-2013  CSCHONG   Revise scripts for UOM AND Pack Checking (CS01)*/
/*************************************************************************/
CREATE PROC [dbo].[isp0000P_EXCEL_AU_ADIDAS_Staging_Custom_Mapping]
      @iFileID    INT,
      @vcUserName CHAR(20),
      @cType      NVARCHAR(20),   --0_check,1_import
      @b_Debug    CHAR(1)=0
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   --SET ANSI_WARNINGS OFF

   DECLARE @c_ExecStatements    NVARCHAR(4000)
          ,@c_ExecArguments     NVARCHAR(4000)
          ,@c_ExecStatements2   NVARCHAR(4000)
          ,@c_ExecStatementsAll NVARCHAR(MAX)
          ,@n_continue          INT
          ,@n_StartTCnt         INT
          ,@c_TargetDBName      NVARCHAR(30)
          ,@c_Language          NVARCHAR(5)


   DECLARE @c_UpdateORIgnore       CHAR(1)
          ,@c_ExportExistsReceipt  CHAR(1)
          ,@c_RemainOrIgnoreDetail CHAR(1)
          ,@c_CONVERTUpperCASESKU  CHAR(1)
          ,@c_SKUORAltSKU          CHAR(1)
          ,@c_ALTSKUField          CHAR(1)
          ,@c_SKUCombine           CHAR(1)
          ,@c_SEPTWOLVESCartON     CHAR(1)
          ,@c_ExplodeBOM           CHAR(1)
          ,@c_cImportFlag          CHAR(1)
          ,@c_Storerkey            NVARCHAR(15)
          ,@c_ExternReceiptkey     CHAR(20)
          ,@n_ExcelRowNo           INT
          ,@c_Facility             NVARCHAR(10)
          ,@c_SKU                  CHAR(20)
          ,@c_AltSKU               CHAR(20)
          ,@c_RetailSKU            CHAR(20)
          ,@c_UPC                  CHAR(30)
          ,@c_Style                CHAR(20)
          ,@c_Color                CHAR(10)
          ,@c_Size                 CHAR(5)
          ,@c_Lottable01           CHAR(20)
          ,@c_Lottable02           CHAR(20)
          ,@c_Lottable03           CHAR(20)
          ,@c_Lottable04           CHAR(20)
          ,@c_Receiptkey           CHAR(10)
          ,@b_success              INT
          ,@c_toLoc                CHAR(10)
          ,@n_iNo                  INT
          ,@c_TempNum              VARCHAR(100)
          ,@c_LineNum              CHAR(5)
          ,@n_iLineNumber          INT
          ,@c_Packkey              CHAR(10)
          ,@c_Packkey_out          NVARCHAR(10)
          ,@c_UOM                  CHAR(10)
          ,@n_SUMQty               INT
          ,@n_Qty                  INT
          ,@n_GetQty               INT
          ,@n_Totalcnt             INT
          ,@n_CntRec               INT
          ,@n_RecCnt               INT
          ,@c_convertFacility      CHAR(1)        --CS04
          ,@c_Facility_Out         NVARCHAR(10)   --CS04
          ,@c_ByPassChecking       CHAR(1)        --CS10
          ,@c_QKSTWCUST            CHAR(1)        --CS11
          ,@c_chkCustValue         NVARCHAR(100)  --CS11
          ,@c_ByPassLottCheck      CHAR(1)        --CS12
          ,@c_GetCarrier           CHAR(1)        --CS15
          ,@c_carrierkey           NVARCHAR(15)   --CS15
          ,@c_GetLott02            CHAR(1)        --CS17
          ,@c_ByPassRecDet         CHAR(1)        --CS20
          ,@c_AutoCreateRI         CHAR(1)        --CS23     
          ,@c_AddRI                CHAR(1)        --CS23
          ,@c_RIECOMRECVID         NVARCHAR(45)   --CS23
          ,@c_RIECOMORDID          NVARCHAR(45)   --CS23
          ,@c_ByPassUPDATERCPHD    CHAR(1)        --CS23a
          ,@n_TTLQty               INT            --ZC37
          ,@n_ORDTTLQty            INT            --ZC37
          ,@c_Configvalue          NVARCHAR(30)   --ZC37
          ,@c_Channel              NVARCHAR(40)   --ZC37
          ,@c_Channel_value        NVARCHAR(40)   --ZC37
          ,@c_ByPassPackKeyVD      NVARCHAR(1)    --(CS24)

DECLARE
           @c_ASNTOORD                 CHAR(1)        --CS21
          ,@c_AddORD                   CHAR(1)        --CS21
          ,@c_ORDExternReceiptkey      NVARCHAR(20)   --CS21
          ,@c_ORDStorerkey             NVARCHAR(15)   --CS21
          ,@c_ORDLottable02            NVARCHAR(20)   --CS21
          ,@c_ORDLottable03            NVARCHAR(20)   --CS21
          ,@c_ORDDUSR01                NVARCHAR(30)   --CS21
          ,@c_ORDExternlineNo          NVARCHAR(10)   --CS21
          ,@c_ORDSKU                   NVARCHAR(20)   --CS21
          ,@n_ORDOpenQty               INT            --CS21
          ,@n_ORDQty                   INT            --CS21
          ,@c_ORDUOM                   NVARCHAR(10)   --CS21
          ,@c_ORDPackkey               NVARCHAR(10)   --CS21
          ,@c_GetORDPackkey            NVARCHAR(10)   --CS21
          ,@c_addwho                   NVARCHAR(20)   --CS21
          ,@c_Orderkey                 NVARCHAR(15)   --CS21
          ,@c_Company                  NVARCHAR(45)   --CS21
          ,@c_address1                 NVARCHAR(45)   --CS21
          ,@c_address2                 NVARCHAR(45)   --CS21
          ,@c_zip                      NVARCHAR(18)   --CS21
          ,@c_country                  NVARCHAR(30)   --CS21
          ,@c_phone1                   NVARCHAR(18)   --CS21
          ,@c_Lot03GenExpiryDate       NVARCHAR(1)   --(CS25)
          ,@c_Lot03GenExpiryDatesubsp  NVARCHAR(250) --(CS25)
          ,@n_err                      INT           --(CS25)
          ,@c_ErrMsg                   NVARCHAR(250) --(CS25) 



   DECLARE @c_vcMsg           NVARCHAR(500)
          ,@c_cMsgType        NVARCHAR(10)
          ,@c_CONfigCode      NVARCHAR(30)
          ,@c_ExcelRowNo      NVARCHAR(15)    --CS13
          ,@c_sValue          CHAR(1)
          ,@c_ChkStatus       NVARCHAR(10)
          ,@c_AltSku_out      NVARCHAR(20)
          ,@c_RetailSku_out   NVARCHAR(20)
          ,@c_UPCSku_out      NVARCHAR(30)
          ,@c_Lottable01_chk  NVARCHAR(20)
          ,@c_Lottable02_chk  NVARCHAR(20)
          ,@c_Lottable03_chk  NVARCHAR(20)
          ,@c_Lottable04_chk  NVARCHAR(20)
          ,@n_iFileID         INT
          ,@c_iFileID         VARCHAR(15)      --CS13
          ,@c_PackUOM1        NVARCHAR(10)
          ,@n_CaseCnt         FLOAT
          ,@c_PackUOM2        NVARCHAR(10)
          ,@n_InnerPack       FLOAT
          ,@c_PackUOM3        NVARCHAR(10)
          ,@n_uom3Qty         FLOAT
          ,@c_PackUOM4        NVARCHAR(10)
          ,@n_Pallet          FLOAT
          ,@c_PACKUOM5        CHAR(10)
          ,@n_Cube            FLOAT
          ,@c_PACKUOM6        CHAR(10)
          ,@n_GrossWgt        FLOAT
          ,@c_PACKUOM7        CHAR(10)
          ,@n_NetWgt          FLOAT
          ,@c_PACKUOM8        CHAR(10)
          ,@n_OtherUnit1      FLOAT
          ,@c_PACKUOM9        CHAR(10)
          ,@n_OtherUnit2      FLOAT
          ,@c_GetSKU          CHAR(1)  --CS03
          ,@d_StartTime       DATETIME --CS06
          ,@n_QtyExpected     INT      --CS08
/*CS05 Start*/
DECLARE   @c_CheckFrmStorer1       CHAR(1)
         ,@c_CheckFrmStorer1Value  NVARCHAR(100)
         ,@c_CheckFrmStorer2       CHAR(1)
         ,@c_CheckFrmStorer2Value  NVARCHAR(100)
         ,@c_CheckFrmStorer3       CHAR(1)
         ,@c_CheckFrmStorer3Value  NVARCHAR(100)
         ,@c_CheckFrmStorer4       CHAR(1)
         ,@c_CheckFrmStorer4Value  NVARCHAR(100)
         ,@c_CheckFrmStorer5       CHAR(1)
         ,@c_CheckFrmStorer5Value  NVARCHAR(100)
         ,@c_notes                 NVARCHAR(100)
         
         ,@c_ExternPOKey           NVARCHAR(20)
         ,@c_ToID                  NVARCHAR(18)
         ,@c_Dusr01                NVARCHAR(30)
         ,@c_PHUserDefine01        NVARCHAR(30)
         ,@c_PHUserDefine02        NVARCHAR(30)
         ,@c_PHUserDefine03        NVARCHAR(30)
         ,@c_PHUserDefine04        NVARCHAR(30)
         ,@c_PHUserDefine05        NVARCHAR(30)
         ,@c_POKey                 NVARCHAR(10)
         ,@c_POExternLineNo        NVARCHAR(10)
         ,@c_POPackKey             NVARCHAR(10)
         ,@c_POUOM                 NVARCHAR(10)
         ,@c_POLineNumber          NVARCHAR(5)
         ,@c_POUserDefine01        NVARCHAR(30)
         ,@c_POUserDefine02        NVARCHAR(30)
         ,@c_POUserDefine03        NVARCHAR(30)
         ,@c_POUserDefine04        NVARCHAR(30)
         ,@c_POUserDefine05        NVARCHAR(30)
         ,@c_POUserDefine09        NVARCHAR(30)
         ,@c_POUserDefine10        NVARCHAR(30)
         ,@c_POLottable02          NVARCHAR(18)
         ,@c_POLottable03          NVARCHAR(18)
         ,@c_POLottable10          NVARCHAR(30)
         ,@c_POType                NVARCHAR(10)
         ,@c_IsFailed              NVARCHAR(1)
         ,@c_PrevDUSR01            NVARCHAR(30)
         ,@c_UCCNo                 NVARCHAR(20)
         ,@c_PrevUCCNo             NVARCHAR(20)
         ,@c_FromID                NVARCHAR(18)
         ,@n_RowCount              INT
         ,@n_RowRef                INT 
         ,@n_UCCRowRef             INT 
         ,@n_NewExcelRowNo         INT 

/*CS05 End*/

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_continue = 1
   SET @c_TargetDBName = ''
   SET @c_Language = ''
   SET @c_vcMsg    = ''
   SET @c_cMsgType = ''
   SET @c_CONfigCode = ''
   SET @c_sValue = ''
   SET @n_RecCnt = 0
   SET @c_ConvertFacility     = '0'   --CS04
   SET @c_ByPassRecDet   = '0'        --CS20
   SET @c_AddORD = 'N'                --CS21
   SET @c_ByPassUPDATERCPHD = '0'     --CS23a
   SET @c_AddRI  ='N'                 --CS23
   SET @c_AutoCreateRI = '0'          --CS23
   SET @c_ByPassUPDATERCPHD = ''      --CS23a
   SET @c_Lot03GenExpiryDate = '0'    --CS25
   SET @c_SKU = ''
   SET @c_PrevDUSR01 = ''
   SET @c_Receiptkey = ''
   SET @c_UCCNo = ''
   SET @c_PrevUCCNo = ''
   SET @c_FromID = ''
   SET @n_UCCRowRef = 0

   IF @cType = 'Receipt'    
   BEGIN
      IF EXISTS (
         SELECT TOP 1 1 FROM ExcelImport_WMSRECEIPT WITH (NOLOCK)
         WHERE  iFileID = @iFileID
         AND cImportFlag IN ('2' ,'3' ,'5')
         --AND ISNULL(ExternPOKey,'') <> ''      
         AND ISNULL(storerkey,'') = @c_StorerKey
         GROUP BY DUSR01, ExternPOKey
         HAVING COUNT(DUSR01) > 1
     )
     BEGIN
         SET @c_cImportFlag = '5'
         SET @c_cMsgType = 'Error'
         SET @c_vcMsg = LTRIM(RTRIM(ISNULL(@c_vcMsg ,''))) + '/UCC is duplicated'
         
         UPDATE ExcelImport_WMSRECEIPT WITH (ROWLOCK)
         SET    cImportFlag = @c_cImportFlag
               ,cMsgType = @c_cMsgType
               ,vcMsg = @c_vcMsg
         WHERE  iFileID = @iFileID
         AND    cImportFlag = '2'
         
         GOTO QUIT 
     END
     
      IF OBJECT_ID ('tempdb..#PODetail') IS NOT NULL 
         DROP TABLE #PODetail
         
      CREATE TABLE [#PODetail] (
         [RowRef]       [INT] IDENTITY(1,1) PRIMARY KEY,
         [ExternReceiptKey] [NVARCHAR] (20) NULL, 
         [Facility]         [NVARCHAR] (10) NULL,
         [ToID]             [NVARCHAR] (18) NULL,
         [QtyOrdered]       [INT] NULL,
         [Storerkey]        [NVARCHAR] (15) NULL,
         [SKU]              [NVARCHAR] (20) NULL,
         [POKey]            [NVARCHAR] (10) NULL,
         [ExternPOKey]      [NVARCHAR] (20) NULL,
         [ExternLineNo]     [NVARCHAR] (20) NULL,
         [PackKey]          [NVARCHAR] (10) NULL,
         [UOM]              [NVARCHAR] (10) NULL,
         [POLineNumber]     [NVARCHAR] (5) NULL,
         [UserDefine01]     [NVARCHAR] (30) NULL,
         [UserDefine02]     [NVARCHAR] (30) NULL,
         [UserDefine03]     [NVARCHAR] (30) NULL,
         [UserDefine04]     [NVARCHAR] (30) NULL,
         [UserDefine05]     [NVARCHAR] (30) NULL,
         [UserDefine09]     [NVARCHAR] (30) NULL,
         [UserDefine10]     [NVARCHAR] (30) NULL,
         [Lottable02]       [NVARCHAR] (18) NULL,
         [Lottable03]       [NVARCHAR] (18) NULL,
         [Lottable10]       [NVARCHAR] (30) NULL
      )
      
      IF OBJECT_ID ('tempdb..#ReceiptStaging') IS NOT NULL 
         DROP TABLE #ReceiptStaging
      
      CREATE TABLE [#ReceiptStaging] (
         [DUSR01]       [NVARCHAR] (30) NULL ,
         [ToID]         [NVARCHAR] (18) NULL,
         [Storerkey]    [NVARCHAR] (15) NULL,
         [ExcelRowNo]   [INT] NULL
      )
   
      INSERT #ReceiptStaging
      SELECT  ISNULL(LTRIM(RTRIM(DUSR01)), '')
            , ISNULL(LTRIM(RTRIM(ToID)), '')
            , ISNULL(LTRIM(RTRIM(StorerKey)), '')        
            , ExcelRowNo
      FROM   ExcelImport_WMSReceipt WITH (NOLOCK)
      WHERE  iFileID = @iFileID
      AND    cImportFlag = '2'
      ORDER BY ExcelRowNo
        
      DECLARE C_Verify_Record CURSOR LOCAL FAST_FORWARD READ_ONLY
      FOR
      SELECT  ISNULL(LTRIM(RTRIM(DUSR01)), '')
            , ISNULL(LTRIM(RTRIM(ToID)), '')
            , ISNULL(LTRIM(RTRIM(StorerKey)), '')        
            , ExcelRowNo
      FROM #ReceiptStaging WITH (NOLOCK)
      ORDER BY ExcelRowNo

      OPEN C_Verify_Record
      FETCH NEXT FROM C_Verify_Record INTO @c_Dusr01, @c_ToID, @c_Storerkey, @c_ExcelRowNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
          SET @n_RowRef = 0
          SET @n_RowCount = 0

          -- Reset SKU
          /*IF @c_PrevDUSR01 <> @c_Dusr01
          BEGIN 
             SET @c_SKU = ''
          END*/ 
          
          -- Retrieve all open PO lines with the UCC
          INSERT #PODetail
          SELECT 
               ISNULL(R.ExternReceiptKey, '') 
             , ISNULL(R.Facility, '')
             , ISNULL(R.ToID, '')
             , ISNULL(PD.QtyOrdered, 0) 
             , ISNULL(PD.Storerkey, '')   
             , ISNULL(PD.SKU, '')
             , ISNULL(PD.POKey, '')
             , ISNULL(PD.ExternPOKey, '')    
             , ISNULL(PD.ExternLineNo, '')
             , ISNULL(PD.PackKey, '')
             , ISNULL(PD.UOM, '')
             , ISNULL(PD.POLineNumber, '')
             , ISNULL(PD.UserDefine01, '')
             , ISNULL(PD.UserDefine02, '')
             , ISNULL(PD.UserDefine03, '')
             , ISNULL(PD.UserDefine04, '')
             , ISNULL(PD.UserDefine05, '')
             , ISNULL(PD.UserDefine09, '')
             , ISNULL(PD.UserDefine10, '')
             , ISNULL(PD.Lottable02, '')
             , ISNULL(PD.Lottable03, '')
             , ISNULL(PD.Lottable10, '')     
          FROM ExcelImport_WMSRECEIPT R WITH (NOLOCK)
          JOIN AUWMS..PODetail PD WITH (NOLOCK) ON PD.UserDefine01 = R.DUSR01 AND R.StorerKey = PD.StorerKey
          JOIN AUWMS..PO WITH (NOLOCK) ON PD.POKey = PO.POKey
          WHERE iFileID = @iFileID
          AND ExcelRowNo = @c_ExcelRowNo
          AND PO.Status < '9'
          AND PD.UserDefine01 = @c_Dusr01
                            
          -- Map SKU, QtyExpected, and ExternPOKey
          /*SELECT TOP 1 
               @n_RowRef      = RowRef 
             , @c_ExternPOKey = ExternPOKey
             , @c_SKU         = SKU
             , @n_QtyExpected = QtyOrdered
          FROM #PODetail WITH (NOLOCK)
          WHERE StorerKey = @c_Storerkey
          AND UserDefine01 = @c_Dusr01
          ORDER BY RowRef*/ 
          --AND SKU <> @c_SKU
          
          IF @@ROWCOUNT > 0
          BEGIN
             /*UPDATE ExcelImport_WMSRECEIPT SET SKU = @c_SKU, QtyExpected = @n_QtyExpected, ExternPOKey = @c_ExternPOKey
             WHERE iFileID = @iFileID
             AND ExcelRowNo = @c_ExcelRowNo
             
             IF @@ERROR <> 0
             BEGIN
                SET @n_continue = 3
                GOTO QUIT
             END
          
             -- Remove the mapped line to avoid duplicates in JOIN
             DELETE FROM #PODetail WHERE RowRef = @n_RowRef*/
          
             IF @b_Debug = 1
             BEGIN
                SELECT @n_RowRef '@n_RowRef', @c_ExternPOKey '@c_ExternPOKey', @c_SKU '@c_SKU', @n_QtyExpected '@n_QtyExpected', @c_Dusr01 '@c_Dusr01'
             END 
             
             -- If multiple SKU per UCC is found, insert new staging records for rest of the SKUs
             /*IF EXISTS (
                SELECT TOP 1 1 FROM AUWMS..PODetail WITH (NOLOCK) 
                WHERE StorerKey = @c_Storerkey
                AND ExternPOKey = @c_ExternPOKey
                AND UserDefine01 = @c_Dusr01
                GROUP BY UserDefine01
                HAVING COUNT(DISTINCT SKU) > 1
             )
             BEGIN
                INSERT #PODetail
                SELECT 
                     PD.UserDefine01
                   , PD.QtyOrdered 
                   , PD.Storerkey   
                   , PD.SKU         
                FROM ExcelImport_WMSRECEIPT R WITH (NOLOCK)
                JOIN AUWMS..PODetail PD WITH (NOLOCK) ON PD.UserDefine01 = R.DUSR01 AND R.StorerKey = PD.StorerKey
                WHERE iFileID = @iFileID
                AND ExcelRowNo = @c_ExcelRowNo
                AND PD.SKU <> @c_SKU*/
                   
             SELECT @n_RowCount = COUNT(1) FROM #PODetail   
                
             WHILE @n_RowCount > 0
             BEGIN
                SELECT TOP 1 @n_RowRef = RowRef FROM #PODetail WITH (NOLOCK)
                WHERE RowRef > @n_RowRef
                ORDER BY RowRef 
                
                IF @b_Debug = 1
                BEGIN
                  PRINT('Splitting lines...' + CAST(@n_RowRef AS NVARCHAR))
                  SELECT '#PODetail', * FROM #PODetail
                END
                 
                INSERT ExcelImport_WMSRECEIPT (
                     ExternReceiptkey
                   --, ReceiptGroup
                   , Storerkey
                   --, ReceiptDate
                   , POKey
                   /*, CarrierKey
                   , CarrierName
                   , CarrierAddress1
                   , CarrierAddress2
                   , CarrierCity
                   , CarrierState
                   , CarrierZip
                   , CarrierReference
                   , WarehouseReference
                   , OriginCountry
                   , DestinationCountry
                   , VehicleNumber
                   , VehicleDate
                   , PlaceOfLoading
                   , PlaceOfDischarge
                   , PlaceOfDelivery
                   , IncoTerms
                   , TermsNote
                   , ContainerKey
                   , Signatory
                   , PlaceofIssue
                   , Notes
                   , ContainerType
                   , ContainerQty
                   , BilledContainerQty
                   , RECType
                   , ASNReason*/
                   , Facility
                   /*, Appointment_No
                   , xDockFlag
                   , Receiptkey
                   , HUSR01
                   , HUSR02
                   , HUSR03
                   , HUSR04
                   , HUSR05
                   , HUSR06
                   , HUSR07
                   , HUSR08
                   , HUSR09
                   , HUSR10
                   , DOCTYPE
                   , RoutingTool
                   , NoOfMasterCtn
                   , NoOfTTLUnit
                   , NoOfPallet
                   , HWeight
                   , WeightUnit
                   , HCube
                   , CubeUnit*/
                   , ExternLineNo
                   , SKU
                   /*, AltSKU
                   , RetailSKU
                   , UPC
                   , Style
                   , Color
                   , Size
                   , ID
                   , DateReceived*/
                   , QtyExpected
                   --, BeforeReceivedQty
                   , UOM
                   , Packkey
                   /*, VesselKey
                   , VoyageKey
                   , XdockKey
                   , ToLoc
                   , ToLot*/
                   , ToID
                   /*, ConditionCode
                   , Lottable01*/
                   , Lottable02
                   , Lottable03
                   /*, Lottable04
                   , Lottable05
                   , CaseCnt
                   , InnerPack
                   , Pallet
                   , DCube
                   , DGrossWgt
                   , DNetWgt
                   , OtherUnit1
                   , OtherUnit2
                   , UnitPrice
                   , ExtendedPrice
                   , SubReasonCode
                   , PutawayLoc*/
                   , POLineNumber
                   , ExternPOKey
                   , DUSR01
                   , DUSR02
                   , DUSR03
                   , DUSR04
                   , DUSR05
                   /*, DUSR06
                   , DUSR07
                   , DUSR08*/
                   , DUSR09
                   , DUSR10
                   , AddWho
                   , AddDate
                   , iFileID
                   , ExcelRowNo
                   , cImportFlag
                   , cMsgType
                   , vcMsg
                   /*, ReceiptLineNumber
                   , Lottable06
                   , Lottable07
                   , Lottable08
                   , Lottable09*/
                   , Lottable10
                   /*, Lottable11
                   , Lottable12
                   , Lottable13
                   , Lottable14
                   , Lottable15
                   , PROCESSTYPE
                   , SellerName
                   , SellerCompany
                   , SellerAddress1
                   , SellerAddress2
                   , SellerAddress3
                   , SellerAddress4
                   , SellerCity
                   , SellerState
                   , SellerZip
                   , SellerCountry
                   , SellerContact1
                   , SellerContact2
                   , SellerPhone1
                   , SellerPhone2
                   , SellerEmail1
                   , SellerEmail2
                   , SellerFax1
                   , SellerFax2
                   , CTNTYPE1
                   , CTNTYPE2
                   , CTNTYPE3
                   , CTNTYPE4
                   , CTNTYPE5
                   , CTNTYPE6
                   , CTNTYPE7
                   , CTNTYPE8
                   , CTNTYPE9
                   , CTNTYPE10
                   , PACKTYPE1
                   , PACKTYPE2
                   , PACKTYPE3
                   , PACKTYPE4
                   , PACKTYPE5
                   , PACKTYPE6
                   , PACKTYPE7
                   , PACKTYPE8
                   , PACKTYPE9
                   , PACKTYPE10
                   , CTNCNT1
                   , CTNCNT2
                   , CTNCNT3
                   , CTNCNT4
                   , CTNCNT5
                   , CTNCNT6
                   , CTNCNT7
                   , CTNCNT8
                   , CTNCNT9
                   , CTNCNT10
                   , CTNQTY1
                   , CTNQTY2
                   , CTNQTY3
                   , CTNQTY4
                   , CTNQTY5
                   , CTNQTY6
                   , CTNQTY7
                   , CTNQTY8
                   , CTNQTY9
                   , CTNQTY10
                   , GIS_ControlNo
                   , Cust_ISA_ControlNo
                   , Cust_GIS_ControlNo
                   , GIS_ProcessTime
                   , Cust_EDIAckTime
                   , FinalizeDate
                   , RIEcomReceiveId
                   , RIEcomOrderId
                   , RIReceiptAmount
                   , RINotes
                   , RINotes2
                   , Channel
                   , Channel_ID
                   , OpenQty
                   , Status
                   , EffectiveDate
                   , MBOLKey
                   , LoadKey
                   , HoldChannel
                   , QtyAdjusted
                   , QtyReceived
                   , FreeGoodQtyExpected
                   , FreeGoodQtyReceived
                   , ExportStatus
                   , SplitPalletFlag
                   , TrackingNo
                   , RIStoreName*/) 
                SELECT 
                     PD.ExternReceiptkey
                   --, R.ReceiptGroup
                   , PD.Storerkey
                   , PD.POKey
                   /*, R.ReceiptDate
                   , R.POKey
                   , R.CarrierKey
                   , R.CarrierName
                   , R.CarrierAddress1
                   , R.CarrierAddress2
                   , R.CarrierCity
                   , R.CarrierState
                   , R.CarrierZip
                   , R.CarrierReference
                   , R.WarehouseReference
                   , R.OriginCountry
                   , R.DestinationCountry
                   , R.VehicleNumber
                   , R.VehicleDate
                   , R.PlaceOfLoading
                   , R.PlaceOfDischarge
                   , R.PlaceOfDelivery
                   , R.IncoTerms
                   , R.TermsNote
                   , R.ContainerKey
                   , R.Signatory
                   , R.PlaceofIssue
                   , R.Notes
                   , R.ContainerType
                   , R.ContainerQty
                   , R.BilledContainerQty
                   , R.RECType
                   , R.ASNReason*/
                   , PD.Facility
                   /*, R.Appointment_No
                   , R.xDockFlag
                   , R.Receiptkey
                   , R.HUSR01
                   , R.HUSR02
                   , R.HUSR03
                   , R.HUSR04
                   , R.HUSR05
                   , R.HUSR06
                   , R.HUSR07
                   , R.HUSR08
                   , R.HUSR09
                   , R.HUSR10
                   , R.DOCTYPE
                   , R.RoutingTool
                   , R.NoOfMasterCtn
                   , R.NoOfTTLUnit
                   , R.NoOfPallet
                   , R.HWeight
                   , R.WeightUnit
                   , R.HCube
                   , R.CubeUnit*/
                   , PD.ExternLineNo
                   , PD.SKU
                   /*, R.AltSKU
                   , R.RetailSKU
                   , R.UPC
                   , R.Style
                   , R.Color
                   , R.Size
                   , R.ID
                   , R.DateReceived*/
                   , PD.QtyOrdered
                   --, R.BeforeReceivedQty
                   , PD.UOM
                   , PD.Packkey
                   /*, R.VesselKey
                   , R.VoyageKey
                   , R.XdockKey
                   , R.ToLoc
                   , R.ToLot*/
                   , PD.ToID
                   /*, R.ConditionCode
                   , R.Lottable01*/
                   , PD.Lottable02
                   , PD.Lottable03
                   /*, R.Lottable04
                   , R.Lottable05
                   , R.CaseCnt
                   , R.InnerPack
                   , R.Pallet
                   , R.DCube
                   , R.DGrossWgt
                   , R.DNetWgt
                   , R.OtherUnit1
                   , R.OtherUnit2
                   , R.UnitPrice
                   , R.ExtendedPrice
                   , R.SubReasonCode
                   , R.PutawayLoc*/
                   , PD.POLineNumber
                   , PD.ExternPOKey
                   , PD.UserDefine01
                   , PD.UserDefine02
                   , PD.UserDefine03
                   , PD.UserDefine04
                   , PD.UserDefine05
                   /*, R.DUSR06
                   , R.DUSR07
                   , R.DUSR08*/
                   , PD.UserDefine09
                   , PD.UserDefine10
                   , @vcUserName
                   , GETDATE()
                   , @iFileID
                   , ExcelRowNo = (SELECT MAX(ExcelRowNo) + 1 FROM ExcelImport_WMSReceipt WITH (NOLOCK) WHERE iFileID = @iFileID)
                   , '2'
                   , ''
                   , ''
                   /*, R.ReceiptLineNumber
                   , R.Lottable06
                   , R.Lottable07
                   , R.Lottable08
                   , R.Lottable09*/
                   , PD.Lottable10
                   /*, R.Lottable11
                   , R.Lottable12
                   , R.Lottable13
                   , R.Lottable14
                   , R.Lottable15
                   , R.PROCESSTYPE
                   , R.SellerName
                   , R.SellerCompany
                   , R.SellerAddress1
                   , R.SellerAddress2
                   , R.SellerAddress3
                   , R.SellerAddress4
                   , R.SellerCity
                   , R.SellerState
                   , R.SellerZip
                   , R.SellerCountry
                   , R.SellerContact1
                   , R.SellerContact2
                   , R.SellerPhone1
                   , R.SellerPhone2
                   , R.SellerEmail1
                   , R.SellerEmail2
                   , R.SellerFax1
                   , R.SellerFax2
                   , R.CTNTYPE1
                   , R.CTNTYPE2
                   , R.CTNTYPE3
                   , R.CTNTYPE4
                   , R.CTNTYPE5
                   , R.CTNTYPE6
                   , R.CTNTYPE7
                   , R.CTNTYPE8
                   , R.CTNTYPE9
                   , R.CTNTYPE10
                   , R.PACKTYPE1
                   , R.PACKTYPE2
                   , R.PACKTYPE3
                   , R.PACKTYPE4
                   , R.PACKTYPE5
                   , R.PACKTYPE6
                   , R.PACKTYPE7
                   , R.PACKTYPE8
                   , R.PACKTYPE9
                   , R.PACKTYPE10
                   , R.CTNCNT1
                   , R.CTNCNT2
                   , R.CTNCNT3
                   , R.CTNCNT4
                   , R.CTNCNT5
                   , R.CTNCNT6
                   , R.CTNCNT7
                   , R.CTNCNT8
                   , R.CTNCNT9
                   , R.CTNCNT10
                   , R.CTNQTY1
                   , R.CTNQTY2
                   , R.CTNQTY3
                   , R.CTNQTY4
                   , R.CTNQTY5
                   , R.CTNQTY6
                   , R.CTNQTY7
                   , R.CTNQTY8
                   , R.CTNQTY9
                   , R.CTNQTY10
                   , R.GIS_ControlNo
                   , R.Cust_ISA_ControlNo
                   , R.Cust_GIS_ControlNo
                   , R.GIS_ProcessTime
                   , R.Cust_EDIAckTime
                   , R.FinalizeDate
                   , R.RIEcomReceiveId
                   , R.RIEcomOrderId
                   , R.RIReceiptAmount
                   , R.RINotes
                   , R.RINotes2
                   , R.Channel
                   , R.Channel_ID
                   , R.OpenQty
                   , R.Status
                   , R.EffectiveDate
                   , R.MBOLKey
                   , R.LoadKey
                   , R.HoldChannel
                   , R.QtyAdjusted
                   , R.QtyReceived
                   , R.FreeGoodQtyExpected
                   , R.FreeGoodQtyReceived
                   , R.ExportStatus
                   , R.SplitPalletFlag
                   , R.TrackingNo
                   , R.RIStoreName*/
                FROM #PODetail PD WITH (NOLOCK)
                WHERE RowRef = @n_RowRef
                GROUP BY
                     PD.ExternReceiptkey
                   , PD.Storerkey
                   , PD.POKey
                   , PD.Facility
                   , PD.ExternLineNo
                   , PD.SKU
                   , PD.QtyOrdered
                   , PD.UOM
                   , PD.Packkey
                   , PD.ToID
                   , PD.Lottable02
                   , PD.Lottable03
                   , PD.POLineNumber
                   , PD.ExternPOKey
                   , PD.UserDefine01
                   , PD.UserDefine02
                   , PD.UserDefine03
                   , PD.UserDefine04
                   , PD.UserDefine05
                   , PD.UserDefine09
                   , PD.UserDefine10
                   , PD.Lottable10 
                   
                SET @n_RowCount = @n_RowCount - 1
             END 
             --END 
          END 
          
          TRUNCATE TABLE #PODetail

          -- Delete the reference line 
          DELETE FROM ExcelImport_WMSReceipt
          WHERE iFileID = @iFileID
          AND ExcelRowNo = @c_ExcelRowNo
                                         
          IF @@ERROR <> 0
          BEGIN
             SET @n_continue = 3
             GOTO QUIT
          END
          
          SET @c_PrevDUSR01 = @c_Dusr01
           
      FETCH NEXT FROM C_Verify_Record INTO @c_Dusr01, @c_ToID, @c_Storerkey, @c_ExcelRowNo   
      END
      CLOSE C_Verify_Record
      DEALLOCATE C_Verify_Record
       
   END 
   ELSE IF @cType = 'UCC'
   BEGIN
      IF EXISTS (
         SELECT TOP 1 1 FROM ExcelImport_WMSUCC WITH (NOLOCK)
         WHERE  iFileID = @iFileID
         AND cImportFlag = '2'
         AND ISNULL(storerkey,'') = @c_StorerKey
         GROUP BY UCCNo
         HAVING COUNT(UCCNo) > 1
     )
     BEGIN
         SET @c_cImportFlag = '5'
         SET @c_cMsgType = 'Error'
         SET @c_vcMsg = LTRIM(RTRIM(ISNULL(@c_vcMsg ,''))) + '/UCC is duplicated'
         
         UPDATE ExcelImport_WMSUCC WITH (ROWLOCK)
         SET    cImportFlag = @c_cImportFlag
               ,cMsgType = @c_cMsgType
               ,vcMsg = @c_vcMsg
         WHERE  iFileID = @iFileID
         AND    cImportFlag = '2'
         
         GOTO QUIT 
     END
     
      IF OBJECT_ID ('tempdb..#RecDetail') IS NOT NULL 
         DROP TABLE #RecDetail
         
      CREATE TABLE [#RecDetail] (
         [RowRef]            [INT] IDENTITY(1,1) PRIMARY KEY,
         [ReceiptKey]        [NVARCHAR] (10) NULL,
         [UserDefine01]      [NVARCHAR] (30) NULL ,
         [QtyExpected]       [INT] NULL,
         [Storerkey]         [NVARCHAR] (15) NULL,
         [SKU]               [NVARCHAR] (20) NULL,
         [POKey]             [NVARCHAR] (10) NULL,
         [POLineNumber]      [NVARCHAR] (5) NULL,
         [ExternPOKey]       [NVARCHAR] (20) NULL,
         [ReceiptLineNumber] [NVARCHAR] (5) NULL
      )
       
      IF OBJECT_ID ('tempdb..#UCCStaging') IS NOT NULL 
         DROP TABLE #UCCStaging
      
      CREATE TABLE [#UCCStaging] (
         [UCCNo]        [NVARCHAR] (30) NULL ,
         [ReceiptKey]   [NVARCHAR] (10) NULL,
         [Storerkey]    [NVARCHAR] (15) NULL,
         [ExcelRowNo]   [INT] NULL
      )
      
      INSERT #UCCStaging
      SELECT  ISNULL(LTRIM(RTRIM(UCCNo)), '')
             , ISNULL(LTRIM(RTRIM(ReceiptKey)), '')
             , ISNULL(LTRIM(RTRIM(StorerKey)), '')        
             , ExcelRowNo
        FROM   ExcelImport_WMSUCC WITH (NOLOCK)
        WHERE  iFileID = @iFileID
        AND    cImportFlag = '2'
        ORDER BY ExcelRowNo
        
       DECLARE C_Verify_Record CURSOR LOCAL FAST_FORWARD READ_ONLY
       FOR
       SELECT  ISNULL(LTRIM(RTRIM(UCCNo)), '')
             , ISNULL(LTRIM(RTRIM(ReceiptKey)), '')
             , ISNULL(LTRIM(RTRIM(StorerKey)), '')        
             , ExcelRowNo
        FROM   #UCCStaging WITH (NOLOCK)
        ORDER BY ExcelRowNo

       OPEN C_Verify_Record
       FETCH NEXT FROM C_Verify_Record INTO @c_UCCNo, @c_Receiptkey, @c_Storerkey, @c_ExcelRowNo
       WHILE @@FETCH_STATUS = 0
       BEGIN
            SET @n_RowRef = 0
            SET @n_RowCount = 0
                        
            -- Reset SKU
            /*IF @c_PrevUCCNo <> @c_UCCNo
            BEGIN 
               SET @c_SKU = ''
            END 
                        
            SELECT TOP 1 
                 @c_ExternReceiptkey = ExternReceiptKey
               , @c_SKU         = SKU
               , @n_QtyExpected = QtyExpected
            FROM AUWMS..ReceiptDetail WITH (NOLOCK)
            WHERE StorerKey = @c_Storerkey
            AND UserDefine01 = @c_UCCNo
            AND SKU <> @c_SKU
            AND ReceiptKey = @c_Receiptkey*/
            INSERT #RecDetail
            SELECT
                 ISNULL(RD.ReceiptKey, '')
               , ISNULL(RD.UserDefine01, '')
               , ISNULL(RD.QtyExpected, '')
               , ISNULL(RD.Storerkey, '')
               , ISNULL(RD.SKU, '')
               , ISNULL(RD.POKey, '')
               , ISNULL(RD.POLineNumber, '')
               , ISNULL(RD.ExternPOKey, '') 
               , ISNULL(RD.ReceiptLineNumber, '')
            FROM ExcelImport_WMSUCC U WITH (NOLOCK)
            JOIN AUWMS..ReceiptDetail RD WITH (NOLOCK) 
               ON RD.ReceiptKey = U.ReceiptKey AND RD.ReceiptKey = @c_Receiptkey
               AND RD.UserDefine01 = U.UCCNo 
               AND U.StorerKey = RD.StorerKey
            JOIN AUWMS..Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
            WHERE iFileID = @iFileID
            AND ExcelRowNo = @c_ExcelRowNo
            AND R.Status < '9'
            
            IF @@ROWCOUNT > 0
            BEGIN
               /*UPDATE ExcelImport_WMSUCC SET SKU = @c_SKU, Qty = @n_QtyExpected
               WHERE iFileID = @iFileID
               AND ExcelRowNo = @c_ExcelRowNo
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  GOTO QUIT
               END*/
               
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_ExternReceiptkey '@c_ExternReceiptkey', @c_SKU '@c_SKU', @n_QtyExpected '@n_QtyExpected', @c_UCCNo '@c_UCCNo'
               END
               
               -- If multiple SKU per UCC is found, insert new staging records for rest of the SKUs
               /*IF EXISTS (
                  SELECT TOP 1 1 FROM AUWMS..ReceiptDetail WITH (NOLOCK) 
                  WHERE StorerKey = @c_Storerkey
                  AND ExternReceiptkey = @c_ExternReceiptkey
                  AND UserDefine01 = @c_UCCNo
                  AND ReceiptKey = @c_Receiptkey
                  GROUP BY UserDefine01
                  HAVING COUNT(DISTINCT SKU) > 1
               )
               BEGIN 
               INSERT #RecDetail
               SELECT
                    RD.ReceiptKey 
                  , RD.UserDefine01
                  , RD.QtyExpected
                  , RD.Storerkey
                  , RD.SKU
               FROM ExcelImport_WMSUCC U WITH (NOLOCK)
               JOIN AUWMS..ReceiptDetail RD WITH (NOLOCK) 
                  ON RD.ReceiptKey = U.ReceiptKey AND RD.ReceiptKey = @c_Receiptkey
                  AND RD.UserDefine01 = U.UCCNo 
                  AND U.StorerKey = RD.StorerKey
               WHERE iFileID = @iFileID
               AND ExcelRowNo = @c_ExcelRowNo
               AND RD.SKU <> @c_SKU*/
               
               SELECT @n_RowCount = COUNT(1) FROM #RecDetail   
                  
               WHILE @n_RowCount > 0
               BEGIN
                  SELECT TOP 1 @n_RowRef = RowRef FROM #RecDetail WITH (NOLOCK)
                  WHERE RowRef > @n_RowRef
                  ORDER BY RowRef
                  
                  INSERT ExcelImport_WMSUCC (
                      UCCNo
                    , Storerkey
                    , ExternKey
                    , SKU
                    , Qty
                    , SourceKey
                    , SourceType
                    , Userdefined01
                    , Userdefined02
                    , Userdefined03
                    , Status
                    , AddWho
                    , AddDate
                    , iFileID
                    , ExcelRowno
                    , cImportFlag
                    , cMsgType
                    , vcMsg
                    , Lot
                    , Loc
                    , Id
                    , Receiptkey
                    , ReceiptLineNumber
                    , Orderkey
                    , OrderLineNumber
                    , WaveKey
                    , PickDetailKey
                    , Userdefined04
                    , Userdefined05
                    , Userdefined06
                    , Userdefined07
                    , Userdefined08
                    , Userdefined09
                    , Userdefined10
                    , UCC_RowRef) 
                  SELECT 
                      U.UCCNo
                    , U.Storerkey
                    , RD.ExternPOKey
                    , RD.SKU
                    , RD.QtyExpected 
                    , U.SourceKey
                    , U.SourceType
                    , U.Userdefined01
                    , U.Userdefined02
                    , U.Userdefined03
                    , U.Status
                    , U.AddWho
                    , U.AddDate
                    , U.iFileID
                    , ExcelRowNo = (SELECT MAX(ExcelRowNo) + 1 FROM ExcelImport_WMSUCC WITH (NOLOCK) WHERE iFileID = @iFileID)
                    , U.cImportFlag
                    , U.cMsgType
                    , U.vcMsg
                    , U.Lot
                    , U.Loc
                    , U.Id
                    , U.Receiptkey
                    , RD.ReceiptLineNumber
                    , U.Orderkey
                    , U.OrderLineNumber
                    , U.WaveKey
                    , U.PickDetailKey
                    , U.Userdefined04
                    , U.Userdefined05
                    , U.Userdefined06
                    , U.Userdefined07
                    , U.Userdefined08
                    , U.Userdefined09
                    , U.Userdefined10
                    , U.UCC_RowRef
                  FROM ExcelImport_WMSUCC U WITH (NOLOCK)
                  JOIN #RecDetail RD WITH (NOLOCK) 
                     ON RD.ReceiptKey = U.ReceiptKey 
                     AND RD.UserDefine01 = U.UCCNo 
                     AND U.StorerKey = RD.StorerKey
                  WHERE iFileID = @iFileID
                  AND ExcelRowNo = @c_ExcelRowNo
                  --AND RD.SKU <> @c_SKU
                  AND RD.ReceiptKey = @c_Receiptkey
                  AND RowRef = @n_RowRef
                  GROUP BY
                      U.UCCNo
                    , U.Storerkey
                    , RD.ExternPOKey
                    , RD.SKU
                    , RD.QtyExpected
                    , U.SourceKey
                    , U.SourceType
                    , U.Userdefined01
                    , U.Userdefined02
                    , U.Userdefined03
                    , U.Status
                    , U.AddWho
                    , U.AddDate
                    , U.iFileID
                    , U.cImportFlag
                    , U.cMsgType
                    , U.vcMsg
                    , U.Lot
                    , U.Loc
                    , U.Id
                    , U.Receiptkey
                    , RD.ReceiptLineNumber
                    , U.Orderkey
                    , U.OrderLineNumber
                    , U.WaveKey
                    , U.PickDetailKey
                    , U.Userdefined04
                    , U.Userdefined05
                    , U.Userdefined06
                    , U.Userdefined07
                    , U.Userdefined08
                    , U.Userdefined09
                    , U.Userdefined10
                    , U.UCC_RowRef   
                    
                  SET @n_RowCount = @n_RowCount - 1
               END 
               --END 
            END 
            
            TRUNCATE TABLE #RecDetail
            
            -- Delete the reference line 
            DELETE FROM ExcelImport_WMSUCC
            WHERE iFileID = @iFileID
            AND ExcelRowNo = @c_ExcelRowNo
          
            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               GOTO QUIT
            END
   
            SET @c_PrevUCCNo = @c_UCCNo
            
       FETCH NEXT FROM C_Verify_Record INTO @c_UCCNo, @c_Receiptkey, @c_Storerkey, @c_ExcelRowNo
       END
       CLOSE C_Verify_Record
       DEALLOCATE C_Verify_Record
   END 
   ELSE IF @cType = 'Transfer'
   BEGIN
      IF OBJECT_ID ('tempdb..#UCC') IS NOT NULL 
         DROP TABLE #UCC
         
      CREATE TABLE [#UCC] (
         [RowRef]        [INT] IDENTITY(1,1) PRIMARY KEY,
         [UCCNo]         [NVARCHAR] (30) NULL,
         [ID]            [NVARCHAR] (18) NULL,
         [StorerKey]     [NVARCHAR] (15) NULL         
      )
       
      IF OBJECT_ID ('tempdb..#TransferStaging') IS NOT NULL 
         DROP TABLE #TransferStaging
      
      CREATE TABLE [#TransferStaging] (
         [FromID]   [NVARCHAR] (18) NULL,
         [Storerkey]    [NVARCHAR] (15) NULL,
         [ExcelRowNo]   [INT] NULL
      )
      
      INSERT #TransferStaging
      SELECT   ISNULL(LTRIM(RTRIM(FromID)), '')
             , ISNULL(LTRIM(RTRIM(FromStorerKey)), '')        
             , ExcelRowNo
        FROM   ExcelImport_WMSTransfer WITH (NOLOCK)
        WHERE  iFileID = @iFileID
        AND    cImportFlag = '2'
        ORDER BY ExcelRowNo
        
       DECLARE C_Verify_Record CURSOR LOCAL FAST_FORWARD READ_ONLY
       FOR
       SELECT  ISNULL(LTRIM(RTRIM(FromID)), '')
             , ISNULL(LTRIM(RTRIM(StorerKey)), '')        
             , ExcelRowNo
        FROM   #TransferStaging WITH (NOLOCK)
        ORDER BY ExcelRowNo

       OPEN C_Verify_Record
       FETCH NEXT FROM C_Verify_Record INTO @c_FromID, @c_Storerkey, @c_ExcelRowNo
       WHILE @@FETCH_STATUS = 0
       BEGIN
            SET @n_RowRef = 0
            SET @n_RowCount = 0
            SET @n_UCCRowRef = 0
         
            SELECT TOP 1 
                 @c_UCCNo         = UCCNo
               , @n_UCCRowRef     = UCC_RowRef
            FROM AUWMS..UCC WITH (NOLOCK)
            WHERE StorerKey = @c_Storerkey
            AND ID = @c_FromID
            AND Status = '1'
            ORDER BY UCC_RowRef
           
            IF @@ROWCOUNT > 0
            BEGIN
               UPDATE ExcelImport_WMSTransfer SET DUSR01 = @c_UCCNo, DUSR02 = @c_UCCNo
               WHERE iFileID = @iFileID
               AND ExcelRowNo = @c_ExcelRowNo
               
               IF @@ERROR <> 0
               BEGIN
                  SET @n_continue = 3
                  GOTO QUIT
               END
               
               IF @b_Debug = 1
               BEGIN
                  SELECT @c_FromID '@c_FromID', @c_UCCNo '@c_UCCNo', @n_UCCRowRef '@n_UCCRowRef'
               END
               
               -- If there is still remaining UCCs in UCC table, insert into staging records 
               IF EXISTS (
                  SELECT TOP 1 1 FROM AUWMS..UCC WITH (NOLOCK) 
                  WHERE StorerKey = @c_Storerkey
                  AND ID = @c_FromID
                  AND UCC_RowRef > @n_UCCRowRef
               )
               BEGIN 
                  INSERT #UCC
                  SELECT UCCNo, ID, StorerKey
                  FROM AUWMS..UCC WITH (NOLOCK)
                  WHERE StorerKey = @c_Storerkey
                  AND ID = @c_FromID
                  AND Status = '1'
                  AND UCC_RowRef > @n_UCCRowRef
                  ORDER BY UCC_RowRef
                  
                  SELECT @n_RowCount = COUNT(1) FROM #UCC   
                     
                  WHILE @n_RowCount > 0
                  BEGIN
                     SELECT TOP 1 @n_RowRef = RowRef FROM #UCC WITH (NOLOCK)
                     WHERE RowRef > @n_RowRef
                     ORDER BY RowRef
                     
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @n_RowRef '@n_RowRef', @n_RowCount '@n_RowCount'
                        SELECT 'UCC', * FROM #UCC 
                     END
               
                     INSERT ExcelImport_WMSTransfer (
                         FromStorerkey
                       , ToStorerkey
                       , Type
                       , GenerateHOCharges
                       , GenerateIS_HICharges
                       , ReLot
                       , ReasonCode
                       , CustomerRefNo
                       , Remarks
                       , Facility
                       , ToFacility
                       , HUSR01
                       , HUSR02
                       , HUSR03
                       , HUSR04
                       , HUSR05
                       , HUSR06
                       , HUSR07
                       , HUSR08
                       , HUSR09
                       , HUSR10
                       , FromSKU
                       , FromLoc
                       , FromLot
                       , FromID
                       , FromQty
                       , FromPackkey
                       , FromUOM
                       , Lottable01
                       , Lottable02
                       , Lottable03
                       , Lottable04
                       , Lottable05
                       , ToSKU
                       , ToLoc
                       , ToLot
                       , ToID
                       , ToQty
                       , ToPackkey
                       , ToUOM
                       , ToLottable01
                       , ToLottable02
                       , ToLottable03
                       , ToLottable04
                       , ToLottable05
                       , DUSR01
                       , DUSR02  
                       , DUSR03
                       , DUSR04
                       , DUSR05
                       , DUSR06
                       , DUSR07
                       , DUSR08
                       , DUSR09
                       , DUSR10
                       , AddWho
                       , AddDate
                       , iFileID
                       , ExcelRowNo
                       , cImportFlag
                       , cMsgType
                       , vcMsg
                       , Lottable06
                       , Lottable07
                       , Lottable08
                       , Lottable09
                       , Lottable10
                       , Lottable11
                       , Lottable12
                       , Lottable13
                       , Lottable14
                       , Lottable15
                       , ToLottable06
                       , ToLottable07
                       , ToLottable08
                       , ToLottable09
                       , ToLottable10
                       , ToLottable11
                       , ToLottable12
                       , ToLottable13
                       , ToLottable14
                       , ToLottable15
                       , FromChannel_ID
                       , ToChannel_ID
                       , FromChannel
                       , ToChannel) 
                     SELECT 
                         T.FromStorerkey
                       , T.ToStorerkey
                       , T.Type
                       , T.GenerateHOCharges
                       , T.GenerateIS_HICharges
                       , T.ReLot
                       , T.ReasonCode
                       , T.CustomerRefNo
                       , T.Remarks
                       , T.Facility
                       , T.ToFacility
                       , T.HUSR01
                       , T.HUSR02
                       , T.HUSR03
                       , T.HUSR04
                       , T.HUSR05
                       , T.HUSR06
                       , T.HUSR07
                       , T.HUSR08
                       , T.HUSR09
                       , T.HUSR10
                       , T.FromSKU
                       , T.FromLoc
                       , T.FromLot
                       , T.FromID
                       , T.FromQty
                       , T.FromPackkey
                       , T.FromUOM
                       , T.Lottable01
                       , T.Lottable02
                       , T.Lottable03
                       , T.Lottable04
                       , T.Lottable05
                       , T.ToSKU
                       , T.ToLoc
                       , T.ToLot
                       , T.ToID
                       , T.ToQty
                       , T.ToPackkey
                       , T.ToUOM
                       , T.ToLottable01
                       , T.ToLottable02
                       , T.ToLottable03
                       , T.ToLottable04
                       , T.ToLottable05
                       , U.UCCNo
                       , U.UCCNo  
                       , T.DUSR03
                       , T.DUSR04
                       , T.DUSR05
                       , T.DUSR06
                       , T.DUSR07
                       , T.DUSR08
                       , T.DUSR09
                       , T.DUSR10
                       , T.AddWho
                       , T.AddDate
                       , T.iFileID
                       , ExcelRowNo = (SELECT MAX(ExcelRowNo) + 1 FROM ExcelImport_WMSTransfer WITH (NOLOCK) WHERE iFileID = @iFileID)
                       , T.cImportFlag
                       , T.cMsgType
                       , T.vcMsg
                       , T.Lottable06
                       , T.Lottable07
                       , T.Lottable08
                       , T.Lottable09
                       , T.Lottable10
                       , T.Lottable11
                       , T.Lottable12
                       , T.Lottable13
                       , T.Lottable14
                       , T.Lottable15
                       , T.ToLottable06
                       , T.ToLottable07
                       , T.ToLottable08
                       , T.ToLottable09
                       , T.ToLottable10
                       , T.ToLottable11
                       , T.ToLottable12
                       , T.ToLottable13
                       , T.ToLottable14
                       , T.ToLottable15
                       , T.FromChannel_ID
                       , T.ToChannel_ID
                       , T.FromChannel
                       , T.ToChannel
                     FROM ExcelImport_WMSTransfer T WITH (NOLOCK)
                     JOIN #UCC U WITH (NOLOCK) ON T.FromID = U.ID AND U.StorerKey = T.FromStorerKey
                     WHERE iFileID = @iFileID
                     AND ExcelRowNo = @c_ExcelRowNo
                     AND RowRef = @n_RowRef
                     GROUP BY
                         T.FromStorerkey
                       , T.ToStorerkey
                       , T.Type
                       , T.GenerateHOCharges
                       , T.GenerateIS_HICharges
                       , T.ReLot
                       , T.ReasonCode
                       , T.CustomerRefNo
                       , T.Remarks
                       , T.Facility
                       , T.ToFacility
                       , T.HUSR01
                       , T.HUSR02
                       , T.HUSR03
                       , T.HUSR04
                       , T.HUSR05
                       , T.HUSR06
                       , T.HUSR07
                       , T.HUSR08
                       , T.HUSR09
                       , T.HUSR10
                       , T.FromSKU
                       , T.FromLoc
                       , T.FromLot
                       , T.FromID
                       , T.FromQty
                       , T.FromPackkey
                       , T.FromUOM
                       , T.Lottable01
                       , T.Lottable02
                       , T.Lottable03
                       , T.Lottable04
                       , T.Lottable05
                       , T.ToSKU
                       , T.ToLoc
                       , T.ToLot
                       , T.ToID
                       , T.ToQty
                       , T.ToPackkey
                       , T.ToUOM
                       , T.ToLottable01
                       , T.ToLottable02
                       , T.ToLottable03
                       , T.ToLottable04
                       , T.ToLottable05
                       , U.UCCNo
                       , U.UCCNo  
                       , T.DUSR03
                       , T.DUSR04
                       , T.DUSR05
                       , T.DUSR06
                       , T.DUSR07
                       , T.DUSR08
                       , T.DUSR09
                       , T.DUSR10
                       , T.AddWho
                       , T.AddDate
                       , T.iFileID
                       , T.cImportFlag
                       , T.cMsgType
                       , T.vcMsg
                       , T.Lottable06
                       , T.Lottable07
                       , T.Lottable08
                       , T.Lottable09
                       , T.Lottable10
                       , T.Lottable11
                       , T.Lottable12
                       , T.Lottable13
                       , T.Lottable14
                       , T.Lottable15
                       , T.ToLottable06
                       , T.ToLottable07
                       , T.ToLottable08
                       , T.ToLottable09
                       , T.ToLottable10
                       , T.ToLottable11
                       , T.ToLottable12
                       , T.ToLottable13
                       , T.ToLottable14
                       , T.ToLottable15
                       , T.FromChannel_ID
                       , T.ToChannel_ID
                       , T.FromChannel
                       , T.ToChannel  
                       
                     SET @n_RowCount = @n_RowCount - 1
                  END 
                  
                  TRUNCATE TABLE #UCC
               END 
            END 
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_continue = 3
               GOTO QUIT
            END
               
       FETCH NEXT FROM C_Verify_Record INTO @c_FromID, @c_Storerkey, @c_ExcelRowNo
       END
       CLOSE C_Verify_Record
       DEALLOCATE C_Verify_Record
   END 

   --END
   QUIT:

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN TRAN

   IF @n_continue = 3
   BEGIN
       IF @@TRANCOUNT > @n_StartTCnt
       BEGIN
           ROLLBACK TRAN
       END
       ELSE
       BEGIN
           WHILE @@TRANCOUNT > @n_StartTCnt
           BEGIN
               COMMIT TRAN
           END
       END

       IF CURSOR_STATUS('LOCAL' ,'C_ExcelImport_CONfig') IN (0 ,1)
       BEGIN
           CLOSE C_ExcelImport_CONfig
           DEALLOCATE C_ExcelImport_CONfig
       END

       IF CURSOR_STATUS('LOCAL' ,'C_Verify_Record') IN (0 ,1)
       BEGIN
           CLOSE C_Verify_Record
           DEALLOCATE C_Verify_Record
       END

       IF CURSOR_STATUS('LOCAL' ,'C_Header_Record') IN (0 ,1)
       BEGIN
           CLOSE C_Header_Record
           DEALLOCATE C_Header_Record
       END

       IF CURSOR_STATUS('LOCAL' ,'C_Detail_Record') IN (0 ,1)
       BEGIN
           CLOSE C_Detail_Record
           DEALLOCATE C_Detail_Record
       END
   END
   ELSE
   BEGIN
       WHILE @@TRANCOUNT > @n_StartTCnt
       BEGIN
           COMMIT TRAN
       END
   END
END

GO