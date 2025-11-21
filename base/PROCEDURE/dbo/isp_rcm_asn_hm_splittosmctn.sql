SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_ASN_HM_SplitToSMCtn                        */
/* Creation Date: 22-Jan-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16138 - IND_HM_SplitASN_into_S_and_SMCarton_CR          */
/*                                                                      */
/* Called By: ASN Dynamic RCM configure at listname 'RCMConfig'         */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_ASN_HM_SplitToSMCtn]
   @c_Receiptkey NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @n_continue           INT,
             @n_cnt                INT,
             @n_starttcnt          INT
               
   DECLARE   @c_doctype            NCHAR(1)
           , @c_Lottable02         NVARCHAR(18) = ''
           , @c_Lottable09         NVARCHAR(30) = ''
           , @c_SKU                NVARCHAR(20) = ''
           , @c_UserDefine01       NVARCHAR(30) = ''
           , @c_Storerkey          NVARCHAR(15) = ''
           , @c_ReceiptLineNumber  NVARCHAR(5)  = ''
           , @n_UserDefine01Cnt    INT
           , @c_NewReceiptKey      NVARCHAR(10) = ''
           , @c_NextReceiveLineNo  NVARCHAR(5) = '0'
   
   CREATE TABLE #TMP_DATA (
         RowRef              INT NOT NULL IDENTITY(1,1) 
       , Receiptkey          NVARCHAR(10) NULL
       , ReceiptLineNumber   NVARCHAR(5)  NULL
       , SKU                 NVARCHAR(20) NULL
       , UserDefine01        NVARCHAR(30) NULL
   )
   
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   INSERT INTO #TMP_DATA (Receiptkey, ReceiptLineNumber, SKU, UserDefine01)
   SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.Sku, RD.UserDefine01
   FROM RECEIPTDETAIL RD (NOLOCK)
   WHERE RD.ReceiptKey = @c_Receiptkey
   ORDER BY RD.ReceiptKey, RD.ReceiptLineNumber

   IF @n_continue IN (1,2)
   BEGIN
      DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      --SELECT RD.Sku, COUNT(DISTINCT RD.Userdefine01)
      --FROM #TMP_DATA RD (NOLOCK)
      --WHERE RD.ReceiptKey = @c_Receiptkey
      --GROUP BY RD.Sku
      --HAVING COUNT(DISTINCT RD.Userdefine01) > 1
      
      SELECT RD.Userdefine01, COUNT(RD.Userdefine01)
      FROM RECEIPTDETAIL RD (NOLOCK)
      WHERE RD.ReceiptKey = @c_Receiptkey
      GROUP BY RD.Userdefine01
      HAVING COUNT(RD.Userdefine01) > 1
      
      OPEN CUR_RD  
      
      FETCH NEXT FROM CUR_RD INTO @c_UserDefine01, @n_UserDefine01Cnt
                              
      WHILE @@FETCH_STATUS <> -1   
      BEGIN
      	IF @c_NewReceiptKey = ''
      	BEGIN
            EXEC nspg_GetKey
                 @KeyName     = 'RECEIPT',
                 @fieldlength = 10,
                 @keystring   = @c_NewReceiptKey OUTPUT,
                 @b_Success   = @b_Success OUTPUT,
                 @n_err       = @n_Err,
                 @c_errmsg    = @c_ErrMsg,
                 @b_resultset = 1,
                 @n_batch     = 1
                 
            IF @c_NewReceiptKey <> ''
            BEGIN
               INSERT INTO RECEIPT
               (
                ReceiptKey,          ExternReceiptKey,    ReceiptGroup,
                StorerKey,           ReceiptDate,         POKey,
                CarrierKey,          CarrierName,         CarrierAddress1,
                CarrierAddress2,     CarrierCity,         CarrierState,
                CarrierZip,          CarrierReference,    WarehouseReference,
                OriginCountry,       DestinationCountry,  VehicleNumber,
                VehicleDate,         PlaceOfLoading,      PlaceOfDischarge,
                PlaceofDelivery,     IncoTerms,           TermsNote,
                ContainerKey,        Signatory,           PlaceofIssue,
                OpenQty,             [Status],            Notes,
                ContainerType,       ContainerQty,        BilledContainerQty,
                RECType,             ASNStatus,           ASNReason,
                Facility,            MBOLKey,             Appointment_No,
                LoadKey,             xDockFlag,           UserDefine01,
                PROCESSTYPE,         UserDefine02,        UserDefine03,
                UserDefine04,        UserDefine05,        UserDefine06,
                UserDefine07,        UserDefine08,        UserDefine09,
                UserDefine10,        DOCTYPE,             RoutingTool,
                CTNTYPE1,            CTNTYPE2,            CTNTYPE3,
                CTNTYPE4,            CTNTYPE5,            CTNTYPE6,
                CTNTYPE7,            CTNTYPE8,            CTNTYPE9,
                CTNTYPE10,           PACKTYPE1,           PACKTYPE2,
                PACKTYPE3,           PACKTYPE4,           PACKTYPE5,
                PACKTYPE6,           PACKTYPE7,           PACKTYPE8,
                PACKTYPE9,           PACKTYPE10,          CTNCNT1,
                CTNCNT2,             CTNCNT3,             CTNCNT4,
                CTNCNT5,             CTNCNT6,             CTNCNT7,
                CTNCNT8,             CTNCNT9,             CTNCNT10,
                CTNQTY1,             CTNQTY2,             CTNQTY3,
                CTNQTY4,             CTNQTY5,             CTNQTY6,
                CTNQTY7,             CTNQTY8,             CTNQTY9,
                CTNQTY10,            NoOfMasterCtn,       NoOfTTLUnit,
                NoOfPallet,          [Weight],            WeightUnit,
                [Cube],              CubeUnit,            GIS_ControlNo,
                Cust_ISA_ControlNo,  Cust_GIS_ControlNo,  GIS_ProcessTime,
                Cust_EDIAckTime,     FinalizeDate,        SellerName,
                SellerCompany,       SellerAddress1,      SellerAddress2,
                SellerAddress3,      SellerAddress4,      SellerCity,
                SellerState,         SellerZip,           SellerCountry,
                SellerContact1,      SellerContact2,      SellerPhone1,
                SellerPhone2,        SellerEmail1,        SellerEmail2,
                SellerFax1,          SellerFax2 )
               SELECT
                @c_NewReceiptKey,    ExternReceiptKey,    ReceiptGroup,
                StorerKey,           ReceiptDate,         POKey,
                CarrierKey,          CarrierName,         CarrierAddress1,
                CarrierAddress2,     CarrierCity,         CarrierState,
                CarrierZip,          CarrierReference,    WarehouseReference,
                OriginCountry,       DestinationCountry,  VehicleNumber,
                VehicleDate,         PlaceOfLoading,      PlaceOfDischarge,
                PlaceofDelivery,     IncoTerms,           TermsNote,
                ContainerKey,        Signatory,           PlaceofIssue,
                OpenQty=0,           [Status]='0',        Notes = 'SM',
                ContainerType,       ContainerQty,        BilledContainerQty,
                RECType,             ASNStatus='0',       ASNReason,
                Facility,            MBOLKey='',          Appointment_No,
                LoadKey='',          xDockFlag,           UserDefine01,
                PROCESSTYPE,         UserDefine02,        UserDefine03,
                UserDefine04,        UserDefine05,        UserDefine06,
                UserDefine07,        UserDefine08,        UserDefine09,
                UserDefine10,        DOCTYPE,             RoutingTool,
                CTNTYPE1,            CTNTYPE2,            CTNTYPE3,
                CTNTYPE4,            CTNTYPE5,            CTNTYPE6,
                CTNTYPE7,            CTNTYPE8,            CTNTYPE9,
                CTNTYPE10,           PACKTYPE1,           PACKTYPE2,
                PACKTYPE3,           PACKTYPE4,           PACKTYPE5,
                PACKTYPE6,           PACKTYPE7,           PACKTYPE8,
                PACKTYPE9,           PACKTYPE10,          CTNCNT1,
                CTNCNT2=0,           CTNCNT3,             CTNCNT4,
                CTNCNT5=0,           CTNCNT6,             CTNCNT7,
                CTNCNT8=0,           CTNCNT9,             CTNCNT10,
                CTNQTY1=0,           CTNQTY2,             CTNQTY3,
                CTNQTY4=0,           CTNQTY5,             CTNQTY6,
                CTNQTY7=0,           CTNQTY8,             CTNQTY9,
                CTNQTY10=0,          NoOfMasterCtn=0,     NoOfTTLUnit=0,
                NoOfPallet=0,        [Weight]=0,          WeightUnit='',
                [Cube]=0,            CubeUnit='',         GIS_ControlNo,
                Cust_ISA_ControlNo,  Cust_GIS_ControlNo,  GIS_ProcessTime,
                Cust_EDIAckTime,     FinalizeDate,        SellerName,
                SellerCompany,       SellerAddress1,      SellerAddress2,
                SellerAddress3,      SellerAddress4,      SellerCity,
                SellerState,         SellerZip,           SellerCountry,
                SellerContact1,      SellerContact2,      SellerPhone1,
                SellerPhone2,        SellerEmail1,        SellerEmail2,
                SellerFax1,          SellerFax2
               FROM RECEIPT AS r WITH(NOLOCK)
               WHERE r.ReceiptKey = @c_ReceiptKey
               
               SELECT @n_err = @@ERROR
                     
               IF @n_err <> 0
               BEGIN   
                  SET @n_continue = 3    
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 62015      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Receipt Table Failed. (isp_RCM_ASN_HM_SplitToSMCtn)'   
                                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
                  GOTO ENDPROC  
               END
            END
         END   --@c_NewReceiptKey = ''
            
         DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT DISTINCT RD.ReceiptLineNumber
         FROM #TMP_DATA RD (NOLOCK)
         --WHERE RD.SKU = @c_SKU
         WHERE RD.UserDefine01 = @c_UserDefine01
         
         OPEN CUR_LOOP  
         
         FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber
                                 
         WHILE @@FETCH_STATUS <> -1   
         BEGIN   
            IF EXISTS(SELECT 1 
                      FROM RECEIPT AS r WITH (NOLOCK)
                      WHERE r.ReceiptKey = @c_NewReceiptKey)
            BEGIN
               
               SET @c_NextReceiveLineNo = RIGHT('0000' +
                                         CONVERT(VARCHAR(5), CAST(@c_NextReceiveLineNo AS INT) + 1),
                                         5)
               
               INSERT INTO RECEIPTDETAIL
                 (
                  ReceiptKey,          ReceiptLineNumber,      ExternReceiptKey,
                  ExternLineNo,        StorerKey,              POKey,
                  Sku,                 AltSku,                 Id,
                  [Status],            DateReceived,           QtyExpected,
                  QtyAdjusted,         QtyReceived,            UOM,
                  PackKey,             VesselKey,              VoyageKey,
                  XdockKey,            ContainerKey,           ToLoc,
                  ToLot,               ToId,                   ConditionCode,
                  Lottable01,          Lottable02,             Lottable03,
                  Lottable04,          Lottable05,             CaseCnt,
                  InnerPack,           Pallet,                 [Cube],
                  GrossWgt,            NetWgt,                 OtherUnit1,
                  OtherUnit2,          UnitPrice,              ExtendedPrice,
                  TariffKey,           FreeGoodQtyExpected,    FreeGoodQtyReceived,
                  SubReasonCode,       FinalizeFlag,           DuplicateFrom,
                  BeforeReceivedQty,   PutawayLoc,             ExportStatus,
                  SplitPalletFlag,     POLineNumber,           LoadKey,
                  ExternPoKey,         UserDefine01,           UserDefine02,
                  UserDefine03,        UserDefine04,           UserDefine05,
                  UserDefine06,        UserDefine07,           UserDefine08,
                  UserDefine09,        UserDefine10,           Lottable06,
                  Lottable07,          Lottable08,             Lottable09,
                  Lottable10,          Lottable11,             Lottable12,
                  Lottable13,          Lottable14,             Lottable15
                 )
               SELECT
                  @c_NewReceiptKey,    @c_NextReceiveLineNo,   ExternReceiptKey,
                  ExternLineNo,        StorerKey,              POKey,
                  Sku,                 AltSku,                 Id,
                  [Status]='0',        DateReceived,           [QtyExpected]=(QtyExpected - QtyReceived),
                  QtyAdjusted=0,       QtyReceived=0,          UOM,
                  PackKey,             VesselKey,              VoyageKey,
                  XdockKey,            ContainerKey,           ToLoc,
                  ToLot='',            ToId='',                ConditionCode='OK',
                  Lottable01,          Lottable02,             Lottable03,
                  Lottable04,          Lottable05,             CaseCnt,
                  InnerPack,           Pallet,                 [Cube],
                  GrossWgt,            NetWgt,                 OtherUnit1,
                  OtherUnit2,          UnitPrice,              ExtendedPrice,
                  TariffKey,           FreeGoodQtyExpected,    FreeGoodQtyReceived,
                  SubReasonCode='',    FinalizeFlag='N',       DuplicateFrom='',
                  BeforeReceivedQty=0, PutawayLoc='',          ExportStatus,
                  SplitPalletFlag,     POLineNumber,           LoadKey='',
                  ExternPoKey,         UserDefine01,           UserDefine02,
                  UserDefine03,        UserDefine04,           UserDefine05,
                  UserDefine06,        UserDefine07,           UserDefine08,
                  UserDefine09,        UserDefine10,           Lottable06,
                  Lottable07,          Lottable08,             Lottable09,
                  Lottable10,          Lottable11,             Lottable12,
                  Lottable13,          Lottable14,             Lottable15
               FROM RECEIPTDETAIL AS r WITH(NOLOCK)
               WHERE r.ReceiptKey = @c_ReceiptKey
               AND   r.ReceiptLineNumber = @c_ReceiptLineNumber
               
               --AND   r.QtyExpected > r.QtyReceived
               --AND   r.FinalizeFlag = CASE WHEN @c_IncludeFinalizedItem = 'Y'
               --                            THEN FinalizeFlag
               --                            ELSE 'N'
               --                       END
               
               SELECT @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN   
                  SET @n_continue = 3    
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 62020      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert ReceiptDetail Table Failed. (isp_RCM_ASN_HM_SplitToSMCtn)'   
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
                  GOTO ENDPROC  
               END
               
               --Delete from original Receiptkey
               DELETE FROM RECEIPTDETAIL
               WHERE ReceiptKey = @c_Receiptkey 
               AND ReceiptLineNumber = @c_ReceiptLineNumber
               
               SELECT @n_err = @@ERROR
               
               IF @n_err <> 0
               BEGIN   
                  SET @n_continue = 3    
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                  SET @n_err = 62025      
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert ReceiptDetail Table Failed. (isp_RCM_ASN_HM_SplitToSMCtn)'   
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
                  GOTO ENDPROC  
               END
            END  -- IF EXISTS
            FETCH NEXT FROM CUR_LOOP INTO @c_ReceiptLineNumber
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP  

         FETCH NEXT FROM CUR_RD INTO @c_UserDefine01, @n_UserDefine01Cnt
      END 
   END
   
   IF EXISTS (SELECT 1 FROM RECEIPT (NOLOCK) WHERE ReceiptKey = @c_Receiptkey AND Notes NOT IN ('S','SM'))
   BEGIN
      BEGIN TRAN
      UPDATE RECEIPT
      SET Notes = 'S', 
          TrafficCop = NULL, 
          EditDate = GETDATE(), 
          EditWho = SUSER_SNAME()
      WHERE Receiptkey = @c_Receiptkey
      
      SET @n_err = @@ERROR    
      
      IF @n_err <> 0     
      BEGIN    
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
         SET @n_err = 62030
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Receipt Table Failed. (isp_RCM_ASN_HM_SplitToSMCtn)'   
                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO ENDPROC  
      END  
   END
   
   IF ISNULL(@c_NewReceiptKey,'') <> ''
      SET @c_errmsg = 'Process Completed! New ASN for SM: ' + @c_NewReceiptKey
      
ENDPROC: 
   IF OBJECT_ID('tempdb..#TMP_DATA') IS NOT NULL
      DROP TABLE #TMP_DATA

   IF CURSOR_STATUS('LOCAL', 'CUR_RD') IN (0 , 1)
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD   
   END
      
   IF @n_continue=3  -- Error Occured - Process And Return
    BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
       execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_ASN_HM_SplitToSMCtn'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
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
END -- End PROC

GO