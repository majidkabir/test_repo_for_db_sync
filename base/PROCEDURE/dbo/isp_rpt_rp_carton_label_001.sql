SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store Procedure: isp_RPT_RP_CARTON_LABEL_001                         */
/* Creation Date: 31-Jul-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-23211 - Carton Label in LOGI                            */
/*                                                                      */
/* Called By: RPT_RP_CARTON_LABEL_001                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 31-Jul-2023  WLChooi  1.0  DevOps Combine Script                     */
/* 09-Sep-2024  Tianlei  1.1  UWP-24051 Global Timezone	(GTZ01)         */
/************************************************************************/
CREATE     PROC [dbo].[isp_RPT_RP_CARTON_LABEL_001]
   @c_Orderkey          NVARCHAR(10) = ''
 , @c_Loadkey           NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @c_Facility         NVARCHAR(5)
         , @c_Storerkey        NVARCHAR(15)
         , @b_success          INT
         , @n_err              INT
         , @c_errmsg           NVARCHAR(250)
         , @n_continue         INT
         , @n_starttcnt        INT

   DECLARE @T_ORDERS TABLE ( Orderkey NVARCHAR(10) )

   DECLARE @T_RESULT TABLE
   (
      [OrderKey]       NVARCHAR(10)
    , [ExternOrderKey] NVARCHAR(50)
    , [C_Company]      NVARCHAR(100)
    , [C_Address1]     NVARCHAR(100)
    , [C_Address2]     NVARCHAR(100)
    , [C_Address3]     NVARCHAR(100)
    , [C_Address4]     NVARCHAR(100)
    , [C_City]         NVARCHAR(100)
    , [C_State]        NVARCHAR(100)
    , [C_Zip]          NVARCHAR(100)
    , [C_Country]      NVARCHAR(100)
    , [ConsigneeKey]   NVARCHAR(15)
    , [Route]          NVARCHAR(10)
    , [CartonNo]       INT
    , [LabelNo]        NVARCHAR(20)
    , [Qty]            INT
    , [Wgt]            FLOAT
    , [DeliveryDate]   DATETIME NULL
    , [ST_Company]     NVARCHAR(100)
    , [ST_Address1]    NVARCHAR(100)
    , [ST_Address2]    NVARCHAR(100)
    , [ST_Address3]    NVARCHAR(100)
    , [ST_City]        NVARCHAR(100)
    , [ST_State]       NVARCHAR(100)
    , [ST_Zip]         NVARCHAR(100)
    , [ST_Country]     NVARCHAR(100)
	, [CurrentDateTime] DATETIME NULL   --GTZ001
   )

   IF ISNULL(TRIM(@c_Orderkey),'') <> ''   --By Orders
   BEGIN
      INSERT INTO @T_ORDERS (Orderkey)
      SELECT @c_Orderkey
   END
   ELSE   --By Load
   BEGIN
      INSERT INTO @T_ORDERS (Orderkey)
      SELECT DISTINCT Orderkey
      FROM LOADPLANDETAIL (NOLOCK)
      WHERE Loadkey = @c_Loadkey
   END

   INSERT INTO @T_RESULT (OrderKey, ExternOrderKey, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, C_City
                        , C_State, C_Zip, C_Country, ConsigneeKey, [Route], CartonNo, LabelNo, Qty, Wgt, DeliveryDate
                        , ST_Company, ST_Address1, ST_Address2, ST_Address3, ST_City, ST_State, ST_Zip, ST_Country, CurrentDateTime)
   SELECT OH.OrderKey
        , OH.ExternOrderKey
        , C_Company = ISNULL(TRIM(OH.C_Company),'')
        , C_Address1 = ISNULL(TRIM(OH.C_Address1),'')
        , C_Address2 = ISNULL(TRIM(OH.C_Address2),'')
        , C_Address3 = ISNULL(TRIM(OH.C_Address3),'')
        , C_Address4 = ISNULL(TRIM(OH.C_Address4),'')
        , C_City = ISNULL(TRIM(OH.C_City),'')
        , C_State = ISNULL(TRIM(OH.C_State),'')
        , C_Zip = ISNULL(TRIM(OH.C_Zip),'')
        , C_Country = ISNULL(TRIM(OH.C_Country),'')
        , OH.ConsigneeKey
        , [Route] = ISNULL(TRIM(OH.[Route]),'')
        , PD.CartonNo
        , PD.LabelNo
        , Qty = SUM(PD.Qty)
        , Wgt = SUM(PD.Qty * S.STDGrossWgt)
        , [dbo].[fnc_ConvSFTimeZone](OH.StorerKey, OH.Facility, OH.DeliveryDate) AS DeliveryDate   --GTZ01
        , ST_Company = ISNULL(TRIM(ST.Company),'')
        , ST_Address1 = ISNULL(TRIM(ST.Address1),'')
        , ST_Address2 = ISNULL(TRIM(ST.Address2),'')
        , ST_Address3 = ISNULL(TRIM(ST.Address3),'')
        , ST_City = ISNULL(TRIM(ST.City),'')
        , ST_State = ISNULL(TRIM(ST.[State]),'')
        , ST_Zip = ISNULL(TRIM(ST.Zip),'')
        , ST_Country = ISNULL(TRIM(ST.Country),'')
		, [dbo].[fnc_ConvSFTimeZone](OH.StorerKey, OH.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
   FROM @T_ORDERS T
   JOIN ORDERS OH (NOLOCK) ON T.Orderkey = OH.OrderKey
   JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
   JOIN SKU S (NOLOCK) ON S.StorerKey = PD.StorerKey AND S.Sku = PD.SKU
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.StorerKey
   GROUP BY OH.OrderKey
          , OH.ExternOrderKey
          , ISNULL(TRIM(OH.C_Company),'')
          , ISNULL(TRIM(OH.C_Address1),'')
          , ISNULL(TRIM(OH.C_Address2),'')
          , ISNULL(TRIM(OH.C_Address3),'')
          , ISNULL(TRIM(OH.C_Address4),'')
          , ISNULL(TRIM(OH.C_City),'')
          , ISNULL(TRIM(OH.C_State),'')
          , ISNULL(TRIM(OH.C_Zip),'')
          , ISNULL(TRIM(OH.C_Country),'')
          , OH.ConsigneeKey
		  , OH.StorerKey                         --GTZ01
		  , OH.Facility                          --GTZ01
          , ISNULL(TRIM(OH.[Route]),'')
          , PD.CartonNo
          , PD.LabelNo
          , OH.DeliveryDate
          , ISNULL(TRIM(ST.Company),'')
          , ISNULL(TRIM(ST.Address1),'')
          , ISNULL(TRIM(ST.Address2),'')
          , ISNULL(TRIM(ST.Address3),'')
          , ISNULL(TRIM(ST.City),'')
          , ISNULL(TRIM(ST.[State]),'')
          , ISNULL(TRIM(ST.Zip),'')
          , ISNULL(TRIM(ST.Country),'')

   SELECT TR.OrderKey
        , TR.ExternOrderKey
        , TR.C_Company
        , TR.C_Address1
        , TR.C_Address2
        , TR.C_Address3
        , TR.C_Address4
        , TR.C_City
        , TR.C_State
        , TR.C_Zip
        , TR.C_Country
        , TR.ConsigneeKey
        , TR.[Route]
        , CartonNo = CAST(TR.CartonNo AS NVARCHAR) + ' / ' 
                   + ISNULL(CAST((SELECT COUNT(DISTINCT T.LabelNo) FROM @T_RESULT T WHERE T.OrderKey = TR.OrderKey) AS NVARCHAR),'0')
        , TR.LabelNo
        , TR.Qty
        , TR.Wgt
        , TR.OrderKey + CAST(TR.CartonNo AS NVARCHAR) AS Group1
        , TR.DeliveryDate
        , ST_Company
        , ST_Address1
        , ST_Address2
        , ST_Address3
        , ST_City
        , ST_State
        , ST_Zip
        , ST_Country
		, CurrentDateTime   --GTZ01
   FROM @T_RESULT TR
   ORDER BY TR.OrderKey, TR.CartonNo

   IF @n_continue = 3 -- Error Occured - Process AND Return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_RP_CARTON_LABEL_001'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   -- RETURN
   END
END

GO