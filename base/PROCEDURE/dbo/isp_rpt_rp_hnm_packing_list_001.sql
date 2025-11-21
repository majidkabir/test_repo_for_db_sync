SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_RP_HNM_PACKING_LIST_001                       */
/* Creation Date: 09-Nov-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-21179 - HNM Packing List                                   */
/*                                                                         */
/* Called By: RPT_RP_HNM_PACKING_LIST_001                                  */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver  Purposes                                     */
/* 09-Nov-2022  WLChooi  1.0  DevOps Combine Script                        */
/***************************************************************************/
CREATE   PROC [dbo].[isp_RPT_RP_HNM_PACKING_LIST_001]
(
   @c_StorerKey NVARCHAR(15)
 , @c_OrderKey  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_HMWHCode_Sender   NVARCHAR(50)
         , @c_HMWHCode_Receiver NVARCHAR(50)
         , @n_DictID            INT          = 0
         , @c_ArticleID         NVARCHAR(100)
         , @n_TotalQty          INT
         , @c_PackingMode       NVARCHAR(1)

   DECLARE @T_HDR_DICT AS TABLE
   (
      DictID    INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
    , Storerkey NVARCHAR(15) NULL
    , Orderkey  NVARCHAR(10) NULL
    , HMOrder   NVARCHAR(50) NULL
    , ProductID NVARCHAR(50) NULL
   )

   DECLARE @T_HDR1 AS TABLE
   (
      DictID         INT
    , SendingCountry NVARCHAR(100) NULL
    , OrderNumber    NVARCHAR(100) NULL
   )

   DECLARE @T_HDR2 AS TABLE
   (
      DictID   INT
    , Sender   NVARCHAR(100) NULL
    , Receiver NVARCHAR(100) NULL
   )

   DECLARE @c_SendingCountry NVARCHAR(30)
         , @c_ProductID      NVARCHAR(30)
         , @c_Sender         NVARCHAR(100)
         , @c_Receiver       NVARCHAR(100)
         , @c_SeasonCode     NVARCHAR(18)
         , @c_HMOrder        NVARCHAR(30)

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ST.Country [SendingCountry]
        , LEFT(OD.Sku, 7) [Product]
        , LA.Lottable12 [HMOrder]
        , ISNULL(CK.Code, '') [Sender]
        , ORD.ConsigneeKey [Receiver]
        , ODT.SeasonCode
   FROM ORDERDETAIL (NOLOCK) OD
   JOIN PICKDETAIL (NOLOCK) PD ON  OD.OrderKey = PD.OrderKey
                               AND OD.OrderLineNumber = PD.OrderLineNumber
                               AND OD.StorerKey = PD.Storerkey
   JOIN LOTATTRIBUTE (NOLOCK) LA ON PD.Lot = LA.Lot AND PD.Sku = LA.Sku AND PD.Storerkey = LA.StorerKey
   JOIN ORDERS (NOLOCK) ORD ON OD.StorerKey = ORD.StorerKey AND OD.OrderKey = ORD.OrderKey
   JOIN STORER (NOLOCK) ST ON OD.StorerKey = ST.StorerKey
   LEFT JOIN CODELKUP CK ON  CK.LISTNAME IN ( 'HMFAC', 'HMCOSFAC', 'HMOSEFAC', 'HMAKTFAC' )
                         AND ORD.StorerKey = CK.Storerkey
   CROSS APPLY (  SELECT TOP 1 Lottable01 AS SeasonCode
                  FROM ORDERDETAIL (NOLOCK)
                  WHERE OrderKey = OD.OrderKey) AS ODT
   WHERE OD.OrderKey = @c_OrderKey
   GROUP BY LA.Lottable12
          , LEFT(OD.Sku, 7)
          , ST.Country
          , ORD.ConsigneeKey
          , ORD.C_contact1
          , CK.Code
          , ODT.SeasonCode

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP
   INTO @c_SendingCountry
      , @c_ProductID
      , @c_HMOrder
      , @c_Sender
      , @c_Receiver
      , @c_SeasonCode

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @n_DictID = 0
      SET @c_ArticleID = TRIM(@c_ProductID) + N'%'

      SELECT @c_HMWHCode_Sender = MAX(CASE WHEN CL.Code = @c_Sender THEN ISNULL(CL.Short, '')
                                           ELSE '' END)
           , @c_HMWHCode_Receiver = MAX(CASE WHEN CL.Code = @c_Receiver THEN ISNULL(CL.Short, '')
                                             ELSE '' END)
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'HMWHCode' AND CL.Code IN ( @c_Sender, @c_Receiver )

      --HDR Dict
      INSERT INTO @T_HDR_DICT (Storerkey, Orderkey, HMOrder, ProductID)
      SELECT @c_StorerKey
           , @c_OrderKey
           , @c_HMOrder
           , @c_ProductID

      SELECT @n_DictID = SCOPE_IDENTITY()

      --Header1
      INSERT INTO @T_HDR1 (DictID, SendingCountry, OrderNumber)
      SELECT @n_DictID
           , @c_SendingCountry AS 'Sending Country'
           , TRIM(@c_HMOrder) + ' ' + TRIM(@c_SeasonCode) AS 'Order Number'

      --Header2
      INSERT INTO @T_HDR2 (DictID, Sender, Receiver)
      SELECT @n_DictID
           , TRIM(@c_HMWHCode_Sender) + @c_Sender AS 'Sender'
           , TRIM(@c_HMWHCode_Receiver) + @c_Receiver AS 'Receiver'

      FETCH NEXT FROM CUR_LOOP
      INTO @c_SendingCountry
         , @c_ProductID
         , @c_HMOrder
         , @c_Sender
         , @c_Receiver
         , @c_SeasonCode
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   SELECT THD.DictID
        , THD.Storerkey
        , THD.Orderkey
        , THD.HMOrder
        , THD.ProductID
        , TH1.SendingCountry
        , TH1.OrderNumber
        , TH2.Sender
        , TH2.Receiver
        , TRIM(THD.Storerkey) + TRIM(THD.Orderkey) + TRIM(THD.HMOrder) + TRIM(THD.ProductID) AS Grp1
   FROM @T_HDR_DICT THD
   JOIN @T_HDR1 TH1 ON TH1.DictID = THD.DictID
   JOIN @T_HDR2 TH2 ON TH2.DictID = TH1.DictID

END

GO