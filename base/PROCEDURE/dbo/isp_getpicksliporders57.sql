SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPickSlipOrders57                            */
/* Creation Date: 08-JUL-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/* Purpose:  Create CJF Pickslip for IDSTW                              */
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder57                  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 2021-11-24   WLChooi  1.1  DevOps Combine Script                     */
/* 2021-11-24   WLChooi  1.1  WMS-18393 - Show ID, Color, Size (WL01)   */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders57] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt       INT            -- Holds the current transaction count
         , @n_Err             INT
         , @b_Success         INT
         , @c_errmsg          INT
   
   DECLARE @n_NoOfPickSlip    INT
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @n_SequenceNo      INT
         
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Sku             NVARCHAR(20)
         , @c_Lot             NVARCHAR(15)
         , @c_Loc             NVARCHAR(15)
         , @c_ID              NVARCHAR(18)
         , @c_DropID          NVARCHAR(20)
   
   SET @n_StartTCnt     = @@TRANCOUNT
   SET @n_Err           = 0
   SET @b_Success       = 1
   SET @c_errmsg        = ''
   
   SET @n_SequenceNo    = 0
   SET @n_NoOfPickSlip  = ''
   SET @c_PickHeaderKey = ''
   SET @c_PickSlipNo    = ''
   
   SET @c_Orderkey      = ''
   SET @c_OrderLineNumber = ''
   SET @c_Storerkey       = ''
   SET @c_Sku             = ''
   SET @c_Lot             = ''
   SET @c_Loc             = ''
   SET @c_ID              = ''
   SET @c_DropID          = ''
   
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   

   CREATE TABLE #TMP_PICK
         (  SeqNo             INT      IDENTITY(1,1)  NOT NULL
         ,  PickSlipNo        NVARCHAR(10)
         ,  LoadKey           NVARCHAR(10)   NULL
         ,  Orderkey          NVARCHAR(10)   NULL
         )

   INSERT INTO #TMP_PICK
         (  PickSlipNo
         ,  LoadKey
         ,  Orderkey
         )
   SELECT   DISTINCT 
            PickSlipNo     = ISNULL(RTRIM(PH.PickHeaderKey),'')
         ,  LoadKey        = @c_LoadKey
         ,  Orderkey       = OH.OrderKey
   FROM LOADPLANDETAIL LD   WITH (NOLOCK)  
   JOIN ORDERS         OH   WITH (NOLOCK) ON (LD.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL     PD   WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   LEFT JOIN PICKHEADER  PH WITH (NOLOCK) ON (LD.LoadKey = PH.ExternOrderKey AND LD.Orderkey = PH.Orderkey AND PH.Zone = '3')
   WHERE LD.LoadKey = @c_LoadKey 
   AND PD.Status  >= '0'

   ORDER BY OH.OrderKey

   BEGIN TRAN
   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1'
      ,TrafficCop = NULL
   WHERE ExternOrderKey = @c_Loadkey
   AND Zone = '3'
   AND PickType = '0'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
      END
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @n_NoOfPickSlip = COUNT(DISTINCT Orderkey)
   FROM #TMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo),'') = ''
   IF @n_NoOfPickSlip = 0
   BEGIN
      GOTO QUIT
   END

   BEGIN TRAN
   EXECUTE nspg_GetKey 'PICKSLIP'
                     , 9
                     , @c_PickHeaderKey OUTPUT
                     , @b_success       OUTPUT
                     , @n_err           OUTPUT
                     , @c_errmsg        OUTPUT
                     , 0
                     , @n_NoOfPickSlip
   COMMIT TRAN

   BEGIN TRAN
   INSERT INTO PICKHEADER
         (  PickHeaderKey
         ,  OrderKey
         ,  ExternOrderKey
         ,  PickType
         ,  Zone
         ,  TrafficCop
         )
   SELECT  'P' + RIGHT ( '000000000' +
                 LTRIM(RTRIM(STR(CAST(@c_PickHeaderKey AS INT) +
                                (SELECT COUNT(DISTINCT Orderkey)
                                 FROM #TMP_PICK AS RANK
                                 WHERE RANK.OrderKey < #TMP_PICK.OrderKey
                                 AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' 
                                )))),9)
      , OrderKey
      , LoadKey
      , '0'
      , '3'
      , ''
   FROM #TMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' 
   GROUP BY LoadKey
         ,  OrderKey
   ORDER BY OrderKey

   UPDATE #TMP_PICK
   SET   PickSlipNo = PICKHEADER.PickHeaderKey
   FROM  PICKHEADER WITH (NOLOCK)
   WHERE PICKHEADER.ExternOrderKey = #TMP_PICK.LoadKey
   AND   PICKHEADER.OrderKey = #TMP_PICK.OrderKey
   AND   PICKHEADER.Zone = '3'
   AND   ISNULL(RTRIM(#TMP_PICK.PickSlipNo),'') = '' 

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN
   DECLARE CUR_AUTOSCAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TMP.Orderkey
         ,TMP.PickSlipNo
   FROM #TMP_PICK  TMP
   WHERE TMP.PickSlipNo <> '' AND TMP.PickSlipNo IS NOT NULL
   AND NOT EXISTS ( SELECT 1 FROM PICKINGINFO PINFO WITH (NOLOCK) 
                    WHERE PINFO.PickSlipNo = TMP.PickSlipNo)

   OPEN CUR_AUTOSCAN
   FETCH NEXT FROM CUR_AUTOSCAN INTO @c_OrderKey
                                   , @c_PickSlipNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SELECT @c_StorerKey = Storerkey
      FROM ORDERS (NOLOCK) 
      WHERE Orderkey = @c_OrderKey

      IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND
                 SValue = '1' AND StorerKey = @c_StorerKey)
      BEGIN 
         INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
         VALUES (@c_PickSlipNo, GetDate(), SUSER_NAME(), NULL)
      END

      FETCH NEXT FROM CUR_AUTOSCAN INTO @c_OrderKey
                                      , @c_PickSlipNo
   END
   CLOSE CUR_AUTOSCAN
   DEALLOCATE CUR_AUTOSCAN

   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TMP.Orderkey
         ,TMP.PickSlipNo
         ,SequenceNo = ISNULL(CONVERT(NVARCHAR(5),MAX(REPLACE(PD.DropID,TMP.PickSlipNo,''))),'0')
   FROM #TMP_PICK  TMP
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (TMP.Orderkey = PD.Orderkey)
   GROUP BY TMP.Orderkey
         ,  TMP.PickSlipNo

   OPEN CUR_ORD
   FETCH NEXT FROM CUR_ORD INTO @c_OrderKey
                              , @c_PickSlipNo
                              , @n_Sequenceno
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DECLARE CUR_PCK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderLineNumber
            ,Storerkey
            ,Sku
            ,Lot
            ,Loc
            ,ID
      FROM PICKDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
      AND  (DropID = '' OR DropID IS NULL)
      AND  Status < '9'

      OPEN CUR_PCK
      FETCH NEXT FROM CUR_PCK INTO @c_OrderLineNumber
                                 , @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot
                                 , @c_Loc
                                 , @c_ID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_DropID = ''

         SELECT TOP 1 @c_DropID =  DropID
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE Orderkey = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber
         AND   Storerkey = @c_Storerkey
         AND   Sku = @c_Sku
         AND   Lot = @c_Lot
         AND   Loc = @c_Loc
         AND   ID  = @c_ID
         AND  (DropID <> '' AND DropID IS NOT NULL)

         IF @c_DropID = ''
         BEGIN
            SET @n_Sequenceno = @n_Sequenceno + 1
            SET @c_DropID = @c_PickSlipNo + CONVERT(NVARCHAR(5), @n_Sequenceno)
         END

         UPDATE PICKDETAIL WITH (ROWLOCK)
            SET DropID  = @c_DropID
            ,   Trafficcop = NULL
            ,   EditDate   = GETDATE()
            ,   EditWho    = SUSER_NAME()
         WHERE Orderkey = @c_OrderKey
         AND   OrderLineNumber = @c_OrderLineNumber
         AND   Storerkey = @c_Storerkey
         AND   Sku = @c_Sku
         AND   Lot = @c_Lot
         AND   Loc = @c_Loc
         AND   ID  = @c_ID

         FETCH NEXT FROM CUR_PCK INTO @c_OrderLineNumber
                                    , @c_Storerkey
                                    , @c_Sku
                                    , @c_Lot
                                    , @c_Loc
                                    , @c_ID
      END
      CLOSE CUR_PCK
      DEALLOCATE CUR_PCK

      FETCH NEXT FROM CUR_ORD INTO @c_OrderKey
                                 , @c_PickSlipNo
                                 , @n_Sequenceno
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   QUIT:

   SELECT DISTINCT
          TMP.PickSlipNo
         ,TMP.Loadkey
         ,TMP.Orderkey
         ,OH.Facility
         ,ISNULL(RTRIM(OH.Route),'')
         ,ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,ISNULL(RTRIM(OH.C_Company),'')
         ,ISNULL(RTRIM(OH.C_Address1),'')
         ,ISNULL(RTRIM(OH.C_Address2),'')
         ,OH.DeliveryDate
         ,ISNULL(RTRIM(OH.Notes),'')
         ,PD.Sku
         ,PD.Loc
         ,ISNULL(RTRIM(SKU.Descr),'')
         ,ISNULL(RTRIM(SKU.SkuGroup),'')
         ,''   --ISNULL(RTRIM(LA.Lottable02),'')   --WL01
         ,NULL --CASE WHEN LA.Lottable04 = '1900-01-01' THEN NULL ELSE LA.Lottable04 END   --WL01
         ,QtyInCarton = CASE WHEN PACK.CaseCnt > 0 THEN FLOOR(SUM(PD.Qty) / PACK.CaseCnt) ELSE 0 END
         ,QtyInEA     = CASE WHEN PACK.CaseCnt > 0 THEN SUM(PD.Qty) % CONVERT(INT,PACK.CaseCnt) ELSE SUM(PD.Qty) END
         ,ID          = PD.ID                  --WL01
         ,Color       = ISNULL(SKU.Color,'')   --WL01
         ,Size        = ISNULL(SKU.Size,'')    --WL01
   FROM #TMP_PICK    TMP
   JOIN ORDERS       OH  WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (TMP.Orderkey = PD.Orderkey)
   JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (PD.Lot = LA.Lot)
   JOIN SKU          SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                       AND(PD.Sku = SKU.Sku)
   JOIN PACK         PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   GROUP BY TMP.PickSlipNo
         ,  TMP.Loadkey
         ,  TMP.Orderkey
         ,  OH.Facility
         ,  ISNULL(RTRIM(OH.Route),'')
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,  ISNULL(RTRIM(OH.C_Company),'')
         ,  ISNULL(RTRIM(OH.C_Address1),'')
         ,  ISNULL(RTRIM(OH.C_Address2),'')
         ,  OH.DeliveryDate
         ,  ISNULL(RTRIM(OH.Notes),'')
         ,  PD.Sku
         ,  PD.Loc
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  ISNULL(RTRIM(SKU.SkuGroup),'')
         --,  ISNULL(RTRIM(LA.Lottable02),'')   --WL01
         --,  CASE WHEN LA.Lottable04 = '1900-01-01' THEN NULL ELSE LA.Lottable04 END   --WL01
         ,  PACK.CaseCnt 
         ,  PD.ID                  --WL01
         ,  ISNULL(SKU.Color,'')   --WL01
         ,  ISNULL(SKU.Size,'')    --WL01
   ORDER BY TMP.PickSlipNo
         ,  TMP.Loadkey
         ,  TMP.Orderkey
         ,  PD.Loc   --WL01
         ,  PD.ID    --WL01
         ,  PD.Sku   --WL01

   DROP Table #TMP_PICK

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO