SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RFID_GetASNKey01                                    */
/* Creation Date: 2020-08-28                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-14739 - CN NIKE O2 WMS RFID Receiving Module           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.8                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 09-OCT-2020 Wan      1.0   Created                                   */
/* 26-Jan-2021 Wan01    1.1   WMS-16143 - NIKE_O2_RFID_Receiving_CR V1.0*/
/* 03-MAR-2021 Wan02    1.2   WMS-16467 - [CN]NIKE_O2_RFID_Receiving_ChangeField_CR*/
/* 2021-03-19  Wan03    1.3   WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving*/
/*                           _Overall_CR                                */
/* 2021-04-13  Wan03    1.4   Fixed Record insert into Receiptdetail_wip*/
/*                            when fial on checklist                    */
/* 2021-05-20  WLChooi  1.5   WMS-16736 - [CN]NIKE_GWP_RFID_Receiving_CR*/
/*                            (WL01)                                    */
/* 2021-07-06  WLChooi  1.6   WMS-17404 - [CN]NIKE PHC Outlets RFID     */
/*                            Receiving CR (WL02)                       */
/* 2022-08-01  WLChooi  1.7   WMS-20357 - Modify Validation (WL03)      */
/* 2022-08-01  WLChooi  1.7   DevOps Combine Script                     */
/* 12-Oct-2023 WLChooi  1.8   Performance Tuning (WL04)                 */
/************************************************************************/
CREATE   PROC [dbo].[isp_RFID_GetASNKey01]
           @c_Facility           NVARCHAR(5)  
         , @c_Storerkey          NVARCHAR(15)
         , @c_RefNo              NVARCHAR(50)
         , @c_ReceiptKey         NVARCHAR(10) = '' OUTPUT
         , @n_SessionID          BIGINT = 0        OUTPUT   --(Wan03)  
         , @c_Remark             NVARCHAR(50) = '' OUTPUT   --WL02      
         , @b_Success            INT          = 1  OUTPUT
         , @n_Err                INT          = 0  OUTPUT
         , @c_ErrMsg             NVARCHAR(255)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT
         , @n_Continue        INT = 1
         , @n_RowID           BIGINT = 0              --(Wan03)

         , @b_QRCode          INT = 0
         , @c_TrackingNo      NVARCHAR(40) = ''
         , @c_CarrierName     NVARCHAR(45) = ''       --(Wan02)
         , @c_SellerPhone1    NVARCHAR(18) = ''

         , @c_ASNReason       NVARCHAR(10) = ''
         , @dt_Orderdate      DATETIME     = NULL
         , @dt_today          DATETIME     = GETDATE()   
         , @n_ValidDay        INT          = 0
         
         , @c_CurrentUser     NVARCHAR(128)= SUSER_SNAME()     --(Wan03)
         , @c_Sku             NVARCHAR(20) = ''                --(Wan03)

         , @c_UserDefine02    NVARCHAR(30) = ''                --WL01  
         , @c_SellerCity      NVARCHAR(45) = ''                --WL03

   DECLARE @tMATCHASN         TABLE
         ( RowRef             INT            IDENTITY(1,1) PRIMARY KEY
         , ReceiptKey         NVARCHAR(10)   DEFAULT('')
         , TrackingNo         NVARCHAR(40)   DEFAULT('')
         , CarrierName        NVARCHAR(45)   DEFAULT('')       --(Wan02)
         , SellerPhone1       NVARCHAR(18)   DEFAULT('')
         , Orderdate          DATETIME                         --(Wan01)
         , SellerCity         NVARCHAR(45)   DEFAULT('')       --WL03
         )
         
   DECLARE @tTrackingNo      TABLE     --2021-01-07  
         ( RowRef             INT            IDENTITY(1,1) PRIMARY KEY  
         , ReceiptKey         NVARCHAR(10)   DEFAULT('')  
         , TrackingNo         NVARCHAR(40)   DEFAULT('')  
         )  
                        
  
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_ReceiptKey = ''
   
   -- FBR v2.2 2020-12-12
   SELECT TOP 1
          @c_ReceiptKey   = RH.ReceiptKey
        , @c_CarrierName = RH.CarrierName                --(Wan02)
        , @c_SellerPhone1 = ISNULL(RH.SellerPhone1,'')
        , @dt_Orderdate   = RH.Userdefine07              --(Wan01)
        , @c_SellerCity   = RH.SellerCity   --WL03
   FROM RECEIPT RH WITH (NOLOCK)
   --JOIN DOCINFO DI WITH (NOLOCK) ON  DI.TableName = 'RECEIPT'  --(Wan03)
   --                              AND RH.ReceiptKey = DI.Key1
   WHERE RH.Receiptkey = @c_RefNo
   AND RH.Storerkey = @c_Storerkey
   AND RH.Facility  = @c_Facility
   AND RH.DocType   = 'R'
   AND RH.[Status]  < '9'
   AND RH.[ASNStatus]  < '9'
   AND NOT EXISTS ( SELECT 1 FROM RECEIPTDETAIL_WIP WIP WITH (NOLOCK)                     --(Wan03)
                    WHERE WIP.Receiptkey  = RH.ReceiptKey 
                    AND WIP.LockDocKey = 'Y' AND WIP.AddWho <> @c_CurrentUser
                  )
 
   IF @c_ReceiptKey = ''     -- Search CarrierName By QRCode, Get SellerPhone1 by matching CarrierName
   BEGIN
      SET @c_CarrierName = ''                                                             --(Wan02)
      SET @c_SellerPhone1 = ''

      --(Wan03) - START
      ; WITH CR ( CarrierName, Sku, ShippedDate ) AS
      (
         SELECT TOP 1 EOH.PlatformOrderNo                                  
               ,EOD.SKU
               ,EOH.ShippedDate                                               
         FROM EXTERNORDERS EOH WITH (NOLOCK) 
         JOIN EXTERNORDERSDETAIL EOD WITH (NOLOCK) ON EOH.ExternOrderkey = EOD.ExternOrderkey
         WHERE EOD.QRCOde = @c_RefNo
         AND   EOD.Storerkey = @c_Storerkey
         AND   EOD.[Status]  <= '9'
         ORDER BY EOH.ShippedDate DESC
      )                                                                        

      --IF @c_CarrierName <> ''   --Get Receiptkey, SellerPhone1 by matching CarrierName  --(Wan03) --(Wan02)
      --BEGIN                                                                             --(Wan03)
         INSERT INTO @tMATCHASN ( ReceiptKey, CarrierName, SellerPhone1, OrderDate, SellerCity)      --(Wan03)--(Wan01)--WL03
         SELECT TOP 1                                                                     --(Wan03) Get Max ShippedDate
                ReceiptKey   = RH.ReceiptKey                                              
              , CarrierName  = ISNULL(RH.CarrierName,'')                                  --(Wan03)
              , SellerPhone1 = ISNULL(RH.SellerPhone1,'')                                 --(Wan03)
              , Orderdate    = ISNULL(RH.Userdefine07,'')                                 --(Wan01)
              , SellerCity   = ISNULL(RH.SellerCity,'')                                   --WL03
         FROM CR
         LEFT JOIN RECEIPT RH WITH (NOLOCK) ON  RH.Storerkey   = @c_Storerkey             --(Wan03)  Get Max ShippedDate's Receiptkey
                                                AND RH.CarrierName = CR.CarrierName
         WHERE RH.Facility  = @c_Facility
         AND RH.DocType   = 'R'
         AND RH.[Status]  < '9'
         AND RH.[ASNStatus]  = '0'                                      --(Wan03) -- Only ASNStatus = '0'                                
         AND EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)   --(Wan03)
                     WHERE RD.ReceiptKey = RH.ReceiptKey   
                     AND RD.Storerkey = @c_Storerkey   --WL04
                     AND RD.Sku = CR.Sku)
         AND NOT EXISTS ( SELECT 1                                      --(Wan03)
                          FROM RECEIPTDETAIL_WIP WIP WITH (NOLOCK)
                          WHERE WIP.Receiptkey  = RH.ReceiptKey 
                          AND WIP.LockDocKey = 'Y' 
                          AND WIP.AddWho <> @c_CurrentUser
                        )           
         ORDER BY CR.ShippedDate DESC                                   --(Wan03)
               ,  RH.AddDate DESC                                       --(Wan03)

         --There are multiple CarrirerName per QRCode & Multiple ReceiptKey per CarrirerName
         --IF EXISTS (SELECT 1 FROM @tMATCHASN WHERE RowRef > 1)
         --BEGIN
         --   SET @n_Continue = 3
         --   SET @n_Err      = 82010
         --   SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Duplicate ASN # for QRCode: ' + @c_RefNo
         --                   + ' (isp_RFID_GetASNKey01)'
         --   GOTO QUIT_SP
         --END
         
         --(Wan03) - END
      
         SELECT TOP 1 @c_ReceiptKey   = T.ReceiptKey
              , @c_CarrierName  = T.CarrierName                --(Wan03)
              , @c_SellerPhone1 = ISNULL(T.SellerPhone1,'')
              , @dt_Orderdate   = T.OrderDate                  --(Wan01)
              , @c_SellerCity   = T.SellerCity   --WL03
         FROM @tMATCHASN T
         ORDER BY RowRef

         --(Wan03) - START - Max shipped Date found but no ASN #
         IF @c_ReceiptKey IS NULL 
         BEGIN
            SET @c_ReceiptKey = ''
            GOTO VALIDATE_ASN
         END
         --(Wan03) - END
         IF @c_ReceiptKey <> ''
         BEGIN
            SET @b_QRCode = 1 
         END 
      --END                                                                         --(Wan03)
   END
   
   IF @c_ReceiptKey = ''   -- Get CarrierName, Receiptkey, SellerPhone1 By TrackingNo        
   BEGIN
      SET @c_CarrierName = ''                                                       --(Wan02)
      SET @c_SellerPhone1 = ''

      INSERT INTO @tMATCHASN ( ReceiptKey, CarrierName, SellerPhone1, OrderDate, SellerCity)   --(Wan01)--(Wan02)--WL03
      SELECT ReceiptKey = RH.ReceiptKey
            ,WarehauseRef = ISNULL(RH.CarrierName,'')                               --(Wan02)
            ,SellerPhone1 = ISNULL(RH.SellerPhone1,'')
            ,OrderDate    = RH.Userdefine07                                         --(Wan01)
            ,SellerCity   = RH.SellerCity                                       --WL03
      FROM  RECEIPT RH WITH (NOLOCK)
      JOIN  DOCINFO DI WITH (NOLOCK) ON  DI.TableName = 'RECEIPT'
                                     AND RH.ReceiptKey = DI.Key1
      WHERE RH.Storerkey = @c_Storerkey
      AND   RH.Facility  = @c_Facility
      AND   RH.DocType   = 'R'
      AND   RH.[Status]  < '9' 
      AND   RH.[ASNStatus]  < '9'  
      AND   DI.[Key2]    = 'TrackingNo'
      AND   DI.[Key3]    = @c_RefNo
      AND NOT EXISTS (  SELECT 1                                                    --(Wan03)
                        FROM RECEIPTDETAIL_WIP WIP WITH (NOLOCK)
                        WHERE WIP.Receiptkey  = RH.ReceiptKey 
                        AND WIP.LockDocKey = 'Y' 
                        AND WIP.AddWho <> @c_CurrentUser
               )   

      IF EXISTS (SELECT 1 FROM @tMATCHASN HAVING COUNT(DISTINCT ReceiptKey) > 1)   --(Wan03)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 82020
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Duplicate ASN # for TrackingNo: ' + @c_RefNo
                           + ' (isp_RFID_GetASNKey01)'
         GOTO QUIT_SP
      END

      SELECT TOP 1 @c_ReceiptKey   = T.ReceiptKey
            , @c_CarrierName = ISNULL(T.CarrierName,'')        --(Wan02)
            , @c_SellerPhone1 = ISNULL(T.SellerPhone1,'')
            , @dt_Orderdate   = T.OrderDate                    --(Wan01)
            , @c_SellerCity   = T.SellerCity   --WL03
      FROM @tMATCHASN T
      ORDER BY RowRef

      IF @c_ReceiptKey <> ''
      BEGIN
         SET @c_TrackingNo = @c_RefNo
         
         INSERT INTO @tTrackingNo (Receiptkey, TrackingNo)  --2021-01-07
         VALUES (@c_ReceiptKey, @c_TrackingNo)
      END 
   END 

   IF @c_ReceiptKey = '' -- Get Receiptkey, SellerPhone1 By CarrierName 
   BEGIN
      INSERT INTO @tMATCHASN ( ReceiptKey, CarrierName, SellerPhone1, OrderDate, SellerCity)    --(Wan03)--(Wan01)--WL03
      SELECT ReceiptKey = RH.ReceiptKey
            ,CarrierName= RH.CarrierName                                --(Wan03)
            ,SellerPhone1= ISNULL(RH.SellerPhone1,'')
            ,Orderdate   = RH.Userdefine07                              --(Wan01)
            ,SellerCity  = RH.SellerCity   --WL03
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE RH.CarrierName = @c_RefNo                                   --(Wan02)
      AND RH.Storerkey = @c_Storerkey
      AND RH.Facility  = @c_Facility
      AND RH.DocType   = 'R'
      AND RH.[Status]  < '9'
      AND RH.[ASNStatus]  < '9'
      AND NOT EXISTS (  SELECT 1                                        --(Wan03)
                        FROM RECEIPTDETAIL_WIP WIP WITH (NOLOCK)
                        WHERE WIP.Receiptkey  = RH.ReceiptKey 
                        AND WIP.LockDocKey = 'Y' 
                        AND WIP.AddWho <> @c_CurrentUser
         )     

      IF EXISTS (SELECT 1 FROM @tMATCHASN WHERE RowRef > 1)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err      = 82040
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Duplicate ASN # for Plat Form #: ' + @c_RefNo
                         + ' (isp_RFID_GetASNKey01)'
         GOTO QUIT_SP
      END

      SELECT TOP 1 @c_ReceiptKey = T.ReceiptKey
            , @c_CarrierName = ISNULL(T.CarrierName,'')     --(Wan02)
            , @c_SellerPhone1 = ISNULL(T.SellerPhone1,'')
            , @dt_Orderdate   = T.OrderDate                 --(Wan01)
            , @c_SellerCity   = T.SellerCity   --WL03
      FROM @tMATCHASN T
      ORDER BY RowRef

      IF @c_ReceiptKey <> ''
      BEGIN
         SET @b_QRCode = 0
         SET @c_CarrierName = @c_RefNo                      --(Wan02)    
      END
   END

   --(Wan03) - START
   -- Get CS System Return Order
   IF @c_ReceiptKey = ''   -- Get CarrierName, Receiptkey, SellerPhone1 By TrackingNo        
   BEGIN
      SET @c_CarrierName = ''                                                      
      SET @c_SellerPhone1 = ''
      
      SELECT TOP 1
          @c_ReceiptKey   = RH.ReceiptKey
        , @c_CarrierName  = RH.CarrierName               
        , @c_SellerPhone1 = ISNULL(RH.SellerPhone1,'')
        , @dt_Orderdate   = RH.Userdefine07 
        , @c_SellerCity   = RH.SellerCity   --WL03
      FROM RECEIPT RH WITH (NOLOCK)
      WHERE RH.Storerkey = @c_Storerkey
      AND RH.Facility  = @c_Facility
      AND RH.CarrierAddress2 = @c_RefNo
      AND RH.DocType   = 'R'
      AND RH.[Status]  < '9'
      AND RH.[ASNStatus]  < '9'
      AND NOT EXISTS ( SELECT 1 FROM RECEIPTDETAIL_WIP WIP WITH (NOLOCK)                   
                       WHERE WIP.Receiptkey  = RH.ReceiptKey 
                       AND WIP.LockDocKey = 'Y' AND WIP.AddWho <> @c_CurrentUser
                     )
   END
   
   VALIDATE_ASN:                                                           --(Wan03)
   --IF ReceiptKey is found and CarrierName/SellerPhone/TrackingNo in CHECKLIST Table, prompt error and update ASNReason 
   IF @c_ReceiptKey <> ''            --2021-01-07
   BEGIN
      --(Wan01) - START
      SET @dt_Orderdate = CONVERT(DATETIME, CONVERT(NVARCHAR(10), @dt_Orderdate, 121))
      IF @dt_Orderdate IS NOT NULL AND CONVERT(NVARCHAR(10), @dt_Orderdate, 121) <> '1900-01-01'
         AND EXISTS (SELECT 1                           --WL03
                     FROM CODELKUP CL (NOLOCK)          --WL03
                     WHERE CL.LISTNAME = 'RCITY'        --WL03
                     AND CL.Long = @c_SellerCity        --WL03
                     AND CL.Code2 = @c_Facility         --WL03
                     AND CL.Storerkey = @c_Storerkey)   --WL03
      BEGIN 
         SET @n_ValidDay = 0
         SELECT TOP 1  @n_ValidDay = CASE WHEN ISNUMERIC(c.UDF02) = 1 THEN c.UDF02 ELSE 0 END
         FROM CODELKUP AS c WITH (NOLOCK)
         WHERE c.ListName = 'RCITY'      --WL03
         --AND   c.Code = '001'          --WL03
         AND c.Long = @c_SellerCity      --WL03
         AND c.Code2 = @c_Facility       --WL03
         AND c.Storerkey = @c_Storerkey
         
         SET @dt_today = CONVERT(DATETIME, CONVERT(NVARCHAR(10), @dt_today, 121))
         IF  @n_ValidDay > 0 AND DATEDIFF(DAY, @dt_Orderdate, @dt_today) > @n_ValidDay  
         BEGIN
            SET @n_Continue = 3
            SET @n_Err      = 82025
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Order is Over ' + CAST(@n_ValidDay AS NVARCHAR) +' days .'
                            + ' (isp_RFID_GetASNKey01)'
            GOTO QUIT_SP
         END
      END
      --(Wan01) - END
      
      IF @c_TrackingNo = ''  
      BEGIN
         INSERT INTO @tTrackingNo (Receiptkey, TrackingNo)
         SELECT  DI.Key1
               , DI.Key3
         FROM  DOCINFO DI WITH (NOLOCK) 
         WHERE DI.TableName = 'RECEIPT' 
         AND   DI.[Key1]    = @c_ReceiptKey      
         AND   DI.[Key2]    = 'TrackingNo' 
         AND   DI.[Key3]    <> '' 
      END
   
      --2020-01-07
      IF EXISTS ( SELECT 1
                  FROM @tTrackingNo TN
                  JOIN DOCINFO DI WITH (NOLOCK) ON  DI.TableName = 'CheckList'
                                                AND TN.TrackingNo = DI.Key1
                  WHERE DI.Storerkey = @c_Storerkey
               )
      BEGIN
         SET @c_ASNReason= 'CHECKLIST'
         SET @n_Continue = 3
         SET @n_Err      = 82030
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Tracking # Found in Customer CheckList.'
                           + ' (isp_RFID_GetASNKey01)'
      END  

      IF @c_CarrierName <> '' AND @c_ASNReason = ''         --(Wan02)
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM DOCINFO DI WITH (NOLOCK)
                     WHERE DI.TableName = 'CheckList'
                     AND   DI.Storerkey = @c_Storerkey
                     AND   DI.Key2      = @c_CarrierName    --(Wan02)
                )
         BEGIN
            SET @c_ASNReason= 'CHECKLIST'
            SET @n_Continue = 3
            SET @n_Err      = 82050
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Sales Order Found in Customer CheckList.'
                            + ' (isp_RFID_GetASNKey01)'
         END 

         IF @c_ASNReason = ''
         BEGIN
            IF @c_SellerPhone1 <> ''
            BEGIN
               IF EXISTS ( SELECT 1
                           FROM DOCINFO DI WITH (NOLOCK)
                           WHERE DI.TableName = 'CheckList'
                           AND   DI.Storerkey = @c_Storerkey
                           AND   DI.Key3      = @c_SellerPhone1
                         )
               BEGIN
                  SET @c_ASNReason= 'CHECKLIST'
                  SET @n_Continue = 3
                  SET @n_Err      = 82060
                  SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Mobile # Found in Customer CheckList.'
                                  + ' (isp_RFID_GetASNKey01)'
               END
            END
         END
      END 

      IF @c_ASNReason <> ''
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END

         UPDATE RECEIPT 
            SET ASNReason = @c_ASNReason
               ,EditWho   = SUSER_SNAME()
               ,EditDate  = GETDATE()
               ,TrafficCop= NULL
         WHERE ReceiptKey = @c_ReceiptKey

         SET @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = CONVERT(CHAR(250),@n_err)  
            SET @n_Err      = 82070
            SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update RECEIPT Table fail.'
                            + ' (isp_RFID_GetASNKey01) (' + @c_ErrMsg + ')'
            GOTO QUIT_SP
         END 
      END 
      
      --Check CarrierName / QRCode from GroupList
      IF EXISTS (SELECT 1 
                  FROM  DOCINFO DI WITH (NOLOCK) 
                  WHERE DI.TableName = 'GROUPLIST' 
                  AND   DI.[Key2]    = @c_CarrierName
                  AND   DI.StorerKey = @c_Storerkey
                  ) 
      BEGIN           
         SET @n_Continue = 3
         SET @n_Err      = 82045
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Plat FROM #: ' + @c_CarrierName +' Found in Customer GroupList.'
                           + ' (isp_RFID_GetASNKey01)'    
         GOTO QUIT_SP
      END
               
      IF @b_QRCode = 1 AND 
         EXISTS ( SELECT 1 
                  FROM  DOCINFO DI WITH (NOLOCK) 
                  WHERE DI.TableName = 'GROUPLIST' 
                  AND   DI.[Key2]    = @c_RefNo
                  AND   DI.StorerKey = @c_Storerkey
                  ) 
      BEGIN           
         SET @n_Continue = 3
         SET @n_Err      = 82046
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': QRCode #: ' + RTRIM(@c_RefNo) +' Found in Customer GroupList.'
                           + ' (isp_RFID_GetASNKey01)'    
         GOTO QUIT_SP
      END
   --(Wan03) - END  
   END
   ELSE IF @c_ReceiptKey = ''  
   BEGIN
      SET @n_Continue = 3
      SET @n_Err      = 82080
      SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': ReceiptKey Not Found/ASN Received/ASN Cancelled/ASN Closed.'
                        + ' (isp_RFID_GetASNKey01)'
      GOTO QUIT_SP
   END
   
   IF @n_SessionID = 0 AND @n_Continue = 1         --2021-04-13 Wan: Fixed Record Inserted to RECEIPTDETAIL_WIP when fail on checklist
   BEGIN 
      INSERT INTO RECEIPTDETAIL_WIP
      (
         -- Rowref -- this column value is auto-generated
         ReceiptKey
      ,  LockDocKey
      )
      VALUES
      (
         @c_ReceiptKey
      ,  'Y'
      )
      
      SET @n_Err = @@ERROR  
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg   = CONVERT(CHAR(250),@n_err)  
         SET @n_Err      = 82090
         SET @c_ErrMsg   = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': INSERT Into RECEIPTDETAIL_WIP Table fail.'
                         + ' (isp_RFID_GetASNKey01) (' + @c_ErrMsg + ')'
         GOTO QUIT_SP
      END
      
      SET @n_RowID = SCOPE_IDENTITY()  
      SET @n_SessionID = @n_RowID  
    
      UPDATE RECEIPTDETAIL_WIP  
         SET SessionID = @n_SessionID  
      WHERE RowID = @n_RowID  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3        
         SET @n_err = 82100  
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Update RECEIPTDETAIL_WIP Failed.'  
                       + ' (isp_RFID_GetASNKey01) (' + @c_ErrMsg + ')' 
         GOTO QUIT_SP  
      END  
   END

   --WL02 S
   IF EXISTS (SELECT 1 
              FROM RECEIPT R (NOLOCK)
              JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'NIKESoldTo' AND CL.Notes = R.UserDefine03 AND CL.Long = 'OUTLET'
                                       AND CL.Storerkey = R.StorerKey
              WHERE R.ReceiptKey = @c_ReceiptKey )
   BEGIN
      SET @c_Remark = N'奥特莱斯订单'
   END
   --WL02 E
   
QUIT_SP:
   --WL01 S
   SELECT @c_UserDefine02 = UserDefine02  
   FROM RECEIPT (NOLOCK)  
   WHERE Receiptkey =  @c_ReceiptKey  

   IF @n_Continue = 3 AND @c_UserDefine02 IN ('21','2')  
   BEGIN
      SET @c_errmsg = @c_errmsg + CHAR(13) + CHAR(13) + CHAR(13) + 'NSQL'+CONVERT(char(5),@n_err)+': Program orders must receive. (isp_RFID_GetASNKey01)'   
   END
   ELSE IF @n_Continue IN (1,2) AND @c_UserDefine02 IN ('21','2')  
   BEGIN
      SET @n_Continue = 2
      SET @b_Success = @n_Continue
      SET @n_err = 81025
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Program orders must receive. (isp_RFID_GetASNKey01)'   
   END
   --WL01 E

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RFID_GetASNKey01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      IF @b_Success <> 2   --WL01
         SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO