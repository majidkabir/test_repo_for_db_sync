SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_UpdateUPSRtnTrackNo                            */
/* Creation Date: 14-Feb-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Update UPS Return Tracking No  (SOS#230376)                 */
/*                                                                      */
/* Called By: Precartonize Packing                                      */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 02-Mar-2012  NJOW01   1.0  Fix OrderLineNumber                       */
/* 14-Mar-2012  NJOW02   1.1  238817-Allow item added to close carton   */
/*                            generate tracking#                        */
/* 19-Mar-2012  Ung      1.2  Add RDT compatible message                */
/* 26-Mar-2012  James    1.3  Restructure the exec statement (james01)  */
/* 11-May-2012  Leong    1.3  SOS# 244058 - Update additional info      */
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_UpdateUPSRtnTrackNo]
     @c_PickSlipNo NVARCHAR(10)
   , @n_CartonNo   Int
   , @b_Success    Int       OUTPUT
   , @n_err        Int       OUTPUT
   , @c_errmsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  Int
         , @n_starttcnt Int
         , @n_RowId     BigInt --NJOW02

   DECLARE @c_UPSRtnTrackNo   NVARCHAR(20)
         , @c_ServiceLevel    NVARCHAR(2)
         , @c_UPSAccNo        NVARCHAR(15)
         , @c_SpecialHandling NVARCHAR(1)
         , @c_spGenTrack      NVARCHAR(30)
         , @c_SQL             NVarChar(max)
         , @c_Facility        NVARCHAR(5)
         , @c_StorerKey       NVARCHAR(15)
         , @c_OrderKey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_Sku             NVARCHAR(20)
         , @n_Qty             Int
         , @c_LabelNo         NVARCHAR(20)

   DECLARE @c_servicetype     NVARCHAR(2)
         , @c_custdunsno      NVARCHAR(9)
         , @c_USPSConfirmNo   NVARCHAR(22)

   DECLARE @c_ExecArguments   NVarChar(4000) -- (james01)
         , @c_ExecArguments2  NVarChar(4000)

   -- SOS# 244058
   DECLARE @c_BuyerPO         NVARCHAR(20)
         , @c_ExternOrderKey  NVARCHAR(50)  --tlting_ext
         , @c_UserDefine01    NVARCHAR(18)
         , @c_ExternLineNo    NVARCHAR(10)

   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = ''

   --NJOW02
   /*DELETE UPSRETURNTRACKNO FROM UPSRETURNTRACKNO
   LEFT JOIN PACKDETAIL PD WITH (NOLOCK) ON (UPSRETURNTRACKNO.PickSlipNo = PD.PickSlipNo
                                        AND UPSRETURNTRACKNO.LabelNo = PD.LabelNo
                                        AND UPSRETURNTRACKNO.Sku = PD.Sku)*/
   UPDATE UPSRETURNTRACKNO WITH (ROWLOCK)
   SET LabelNo = '',
       OrderLineNumber = ''
   FROM UPSRETURNTRACKNO
   LEFT JOIN PACKDETAIL PD WITH (NOLOCK) ON (UPSRETURNTRACKNO.PickSlipNo = PD.PickSlipNo
                                        AND UPSRETURNTRACKNO.LabelNo = PD.LabelNo
                                AND UPSRETURNTRACKNO.Sku = PD.Sku)
   WHERE ISNULL(RTRIM(PD.LabelLine),'') = ''
   AND UPSRETURNTRACKNO.PickSlipNo = @c_PickSlipNo

   /*IF (SELECT COUNT(*)
       FROM UPSRETURNTRACKNO UTN WITH (NOLOCK)
       JOIN PACKDETAIL PD WITH (NOLOCK) ON UTN.PickSlipNo = PD.PickSlipNo AND UTN.LabelNo = PD.LabelNo
                                      AND UTN.Sku = PD.Sku
       WHERE PD.PickSlipNo = @c_PickSlipNo
       AND PD.CartonNo = @n_CartonNo) > 0  */
   IF (SELECT COUNT(*) --NJOW02
       FROM (SELECT PD.Sku
             FROM PACKDETAIL PD WITH (NOLOCK)
             LEFT JOIN UPSRETURNTRACKNO RTN WITH (NOLOCK) ON (PD.PickSlipNo = RTN.PickSlipNo AND PD.Sku = RTN.Sku AND PD.LabelNo = RTN.LabelNo)
             WHERE PD.PickSlipNo = @c_PickSlipNo
             AND PD.CartonNo = @n_CartonNo
             GROUP BY PD.Sku, PD.Qty
             HAVING PD.Qty - SUM(ISNULL(RTN.Qty,0)) > 0) AS EMPTYTRACK) = 0
   BEGIN
      GOTO EXIT_PROC
   END

   /*SELECT @c_ServiceLevel = ORDERS.M_Phone2,
          @c_SpecialHandling = ORDERS.SpecialHandling,
          @c_StorerKey = ORDERS.StorerKey, @c_Facility = ORDERS.Facility, @c_OrderKey = ORDERS.OrderKey,
          @c_ServiceType = LEFT(ISNULL(ORDERS.Userdefine01,''),2), @c_CustDUNSNo = LEFT(ISNULL(ORDERS.Userdefine02,''),9)
   FROM PACKHEADER WITH (NOLOCK)
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   JOIN ORDERDETAIL WITH (NOLOCK) ON ((Packheader.ConsoOrderKey = Orderdetail.consoOrderKey AND ISNULL(Orderdetail.ConsoOrderKey,'')<>'') OR Packheader.OrderKey = Orderdetail.OrderKey )
   JOIN Orders WITH (NOLOCK) ON ( Orderdetail.OrderKey = Orders.OrderKey)
   -- JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   AND PACKDETAIL.CartonNo = @n_CartonNo
   GROUP BY ORDERS.M_Phone2, ORDERS.SpecialHandling,
            ORDERS.StorerKey, ORDERS.Facility, ORDERS.OrderKey,
            LEFT(ISNULL(ORDERS.Userdefine01,''),2), LEFT(ISNULL(ORDERS.Userdefine02,''),9)*/

   SELECT OD.OrderKey, OD.OrderLineNumber, OD.Sku,
          (OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty) - SUM(ISNULL(RTN.Qty,0)) AS Qty
   INTO #TMP_ORDERDETAIL
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PH.OrderKey = OD.OrderKey)
   LEFT JOIN UPSRETURNTRACKNO RTN WITH (NOLOCK) ON (OD.OrderKey = RTN.OrderKey AND OD.OrderLineNumber = RTN.OrderLineNumber AND OD.Sku = RTN.Sku)
   WHERE PH.PickSlipNo = @c_PickSlipNo
   GROUP BY OD.OrderKey, OD.OrderLineNumber, OD.Sku, OD.QtyAllocated, OD.QtyPicked, OD.ShippedQty
   HAVING (OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty ) - SUM(ISNULL(RTN.Qty,0)) > 0

   DECLARE CUR_GS1RTNLABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      -- SELECT ORDERS.M_Phone2 --AAY20120228
      SELECT
            ( SELECT ISNULL(CODELKUP.SHORT,'') FROM CODELKUP WITH (NOLOCK)
              WHERE CODELKUP.ListName = @c_StorerKey AND RIGHT(CODELKUP.CODE,3) = @c_Facility )
             , ORDERS.SpecialHandling
             , ORDERS.StorerKey
             , ORDERS.Facility
             , ORDERS.OrderKey
             , LEFT(ISNULL(ORDERS.Userdefine01,''),2)
             , LEFT(ISNULL(ORDERS.Userdefine02,''),9)
             ,' ' AS OrderLineNumber
             , PACKDETAIL.Sku
             , PACKDETAIL.Qty - SUM(ISNULL(RTN.Qty,0)) AS Qty --NJOW02
             , PACKDETAIL.LabelNo
      FROM PACKHEADER WITH (NOLOCK)
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
      JOIN ORDERS WITH (NOLOCK) ON (PACKHEADER.OrderKey = ORDERS.OrderKey)
      -- JOIN ORDERDETAIL WITH (NOLOCK) ON ((Packheader.ConsoOrderKey = Orderdetail.consoOrderKey AND ISNULL(Orderdetail.ConsoOrderKey,'')<>'') OR Packheader.OrderKey = Orderdetail.OrderKey )
      -- JOIN Orders WITH (NOLOCK) ON ( Orderdetail.OrderKey = Orders.OrderKey)
      -- JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey AND PACKDETAIL.Sku = ORDERDETAIL.Sku)
      LEFT JOIN UPSRETURNTRACKNO RTN WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = RTN.PickSlipNo --NJOW02
                                                   AND PACKDETAIL.LabelNo = RTN.LabelNo
                                                   AND PACKDETAIL.Sku = RTN.Sku)
      WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
      AND PACKDETAIL.CartonNo = @n_CartonNo
      GROUP BY ORDERS.M_Phone2
             , ORDERS.SpecialHandling
             , ORDERS.StorerKey
             , ORDERS.Facility
             , ORDERS.OrderKey
             , LEFT(ISNULL(ORDERS.Userdefine01,''),2)
             , LEFT(ISNULL(ORDERS.Userdefine02,''),9)
             , PACKDETAIL.Sku
             , PACKDETAIL.Qty
             , PACKDETAIL.LabelNo
      HAVING PACKDETAIL.Qty - SUM(ISNULL(RTN.Qty,0)) > 0  --NJOW02

   OPEN CUR_GS1RTNLABEL
   FETCH NEXT FROM CUR_GS1RTNLABEL INTO @c_ServiceLevel, @c_SpecialHandling, @c_StorerKey, @c_Facility
                                      , @c_OrderKey, @c_ServiceType, @c_CustDUNSNo, @c_OrderLineNumber, @c_Sku, @n_Qty, @c_LabelNo

   WHILE @@FETCH_STATUS <> - 1
   BEGIN
      IF ISNULL(@c_UPSAccNo,'') = ''
      BEGIN
         SELECT TOP 1 @c_UPSAccNo = Long
         FROM CODELKUP WITH (NOLOCK)
         WHERE ListName = @c_StorerKey
         AND Code = 'UPSRET' + LTRIM(RTRIM(@c_Facility))

         IF ISNULL(@c_UPSAccNo,'') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 75801
            SELECT @c_errmsg = 'No account number in system. Please check WMS order #' + RTRIM(@c_OrderKey) + '. Nothing is generated. (isp_UpdateUPSRtnTrackNo)'
            GOTO EXIT_PROC
         END
      END

      IF ISNULL(@c_spGenTrack,'') = ''
      BEGIN
         SELECT @c_spGenTrack = Long
         FROM CODELKUP WITH (NOLOCK)
         WHERE CODELKUP.ListName = '3PSType'
         AND CODELKUP.Code = @c_SpecialHandling

         IF ISNULL(@c_spGenTrack,'') = ''
         BEGIN
            SET @c_spGenTrack = 'isp_GenUPSTrackNo'
         END

         SET @c_spGenTrack = '[dbo].[' + ISNULL(RTRIM(@c_spGenTrack),'') + ']'

         IF NOT EXISTS( SELECT 1 FROM sys.objects
                        WHERE object_id = OBJECT_ID(@c_spGenTrack)
                        AND Type IN (N'P', N'PC') )
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 75802
            SELECT @c_errmsg = 'Stored Procedure ' + RTRIM(@c_spGenTrack) + ' Not Exists in Database(isp_UpdateUPSRtnTrackNo)'
            GOTO EXIT_PROC
         END
      END

      SELECT @c_ServiceType = '', @c_CustDUNSNo = ''

      IF ISNULL(@c_ServiceLevel,'') = ''
      BEGIN
         -- SELECT @c_ServiceLevel = '66'
         SELECT @c_ServiceLevel = '90' --AAY20120228
      END

      WHILE @n_Qty > 0
      BEGIN
         --NJOW02
         SET @n_RowId = 0

         SELECT TOP 1 @n_RowId = RowId
         FROM UPSRETURNTRACKNO WITH (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
         AND OrderKey = @c_OrderKey
         AND Sku = @c_Sku
         AND ISNULL(LabelNo,'') = ''
         AND ISNULL(OrderLineNumber,'') = ''

         IF ISNULL(@n_RowId,0) = 0 --NJOW02
         BEGIN
            -- (james01)
            SET @c_SQL = N'EXEC ' +  @c_spGenTrack + ' @c_UPSAccNo, @c_ServiceLevel, @c_ServiceType, @c_CustDUNSNo, @c_StorerKey, @c_UPSRtnTrackNo OUTPUT, @c_USPSConfirmNo OUTPUT, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT'
            SET @c_ExecArguments  = N' @c_UPSAccNo NVARCHAR(15), @c_ServiceLevel NVARCHAR(2), @c_ServiceType NVARCHAR(2), @c_CustDUNSNo NVARCHAR(9), @c_StorerKey NVARCHAR(15), @c_UPSRtnTrackNo NVARCHAR(20) OUTPUT, '
            SET @c_ExecArguments2 = N' @c_USPSConfirmNo NVARCHAR(22) OUTPUT, @b_Success Int OUTPUT, @n_err Int OUTPUT, @c_errmsg NVARCHAR(250) OUTPUT'
            SET @c_ExecArguments = RTRIM(@c_ExecArguments) + @c_ExecArguments2

            EXEC sp_ExecuteSql  @c_SQL
                              , @c_ExecArguments
                              , @c_UPSAccNo
                              , @c_ServiceLevel
                              , @c_ServiceType
                              , @c_CustDUNSNo
                              , @c_StorerKey
                              , @c_UPSRtnTrackNo OUTPUT
                              , @c_USPSConfirmNo OUTPUT
                              , @b_Success       OUTPUT
                              , @n_err           OUTPUT
                              , @c_errmsg        OUTPUT

            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 75803
               SELECT @c_errmsg = 'isp_UpdateUPSRtnTrackNo: ' + RTRIM(ISNULL(@c_errmsg,''))
               GOTO EXIT_PROC
            END
         END

         SELECT @c_OrderLineNumber = MIN(OrderLineNumber)
         FROM #TMP_ORDERDETAIL
         WHERE OrderKey = @c_OrderKey
         AND Qty > 0
         AND Sku = @c_Sku

         IF ISNULL(@c_OrderLineNumber,'') = ''
         BEGIN
            SELECT @c_OrderLineNumber = MIN(OrderLineNumber)
            FROM ORDERDETAIL WITH (NOLOCK)
            WHERE OrderKey = @c_OrderKey
            AND Sku = @c_Sku
         END
         ELSE
         BEGIN
            UPDATE #TMP_ORDERDETAIL
            SET Qty = Qty - 1
            WHERE OrderKey = @c_OrderKey
            AND OrderLineNumber = @c_OrderLineNumber
            AND Sku = @c_Sku
         END

         IF ISNULL(@n_RowId,0) > 0  --NJOW02
         BEGIN
            UPDATE UPSRETURNTRACKNO WITH (ROWLOCK)
            SET LabelNo = @c_LabelNo,
                OrderLineNumber = @c_OrderLineNumber
            WHERE RowId = @n_RowId
         END
         ELSE
         BEGIN
            INSERT INTO UPSRETURNTRACKNO (PickSlipNo, LabelNo, OrderKey, OrderLineNumber, Sku, Qty, RefNo01)
            VALUES (@c_PickSlipNo, @c_LabelNo, @c_OrderKey, @c_OrderLineNumber, @c_Sku, 1, @c_UPSRtnTrackNo)
         END

         SELECT @n_Qty = @n_Qty - 1

         --SOS# 244058 (Start)
         SET @c_BuyerPO        = ''
         SET @c_ExternOrderKey = ''
         SET @c_UserDefine01   = ''
         SET @c_ExternLineNo   = ''

         SELECT @c_BuyerPO         = O.BuyerPO
               , @c_ExternOrderKey = O.ExternOrderKey
               , @c_UserDefine01   = OD.UserDefine01
               , @c_ExternLineNo   = OD.ExternLineNo
         FROM ORDERS O WITH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK)
         ON (O.OrderKey = OD.OrderKey)
         WHERE O.OrderKey = @c_OrderKey
         AND OD.OrderLineNumber = @c_OrderLineNumber

         UPDATE UPSRETURNTRACKNO WITH (ROWLOCK)
         SET RefNo02  = @c_BuyerPO
            , RefNo03 = @c_ExternOrderKey
            , RefNo04 = @c_UserDefine01
            , RefNo05 = @c_ExternLineNo
         WHERE OrderKey = @c_OrderKey
         AND OrderLineNumber = @c_OrderLineNumber
         AND ISNULL(RTRIM(RefNo05),'') = ''
         --SOS# 244058 (End)
      END

      FETCH NEXT FROM CUR_GS1RTNLABEL INTO @c_ServiceLevel, @c_SpecialHandling, @c_StorerKey, @c_Facility
                                         , @c_OrderKey , @c_ServiceType, @c_CustDUNSNo, @c_OrderLineNumber, @c_Sku, @n_Qty, @c_LabelNo
   END
   CLOSE CUR_GS1RTNLABEL
   DEALLOCATE CUR_GS1RTNLABEL

EXIT_PROC:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT Int
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1 -- (ChewKP05)
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
         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_UpdateUPSRtnTrackNo'
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