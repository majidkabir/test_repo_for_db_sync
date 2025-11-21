SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure: isp_Packing_List_58_rdt                                   */
/* Creation Date: 28-JAN-2019                                                 */
/* Copyright: IDS                                                             */
/* Written by: CSCHONG                                                        */
/*                                                                            */
/* Purpose: WMS-7765-[CN]AFL Packling list_Report                             */
/*                                                                            */
/*                                                                            */
/* Called By:  r_dw_packing_list_58_rdt                                       */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/******************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_58_rdt]
       (@c_Orderkey NVARCHAR(10),
        @c_LabelNo  NVARCHAR(20))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_MCompany        NVARCHAR(45)
         , @c_Externorderkey  NVARCHAR(30)
         , @c_C_Addresses     NVARCHAR(200)
         , @c_loadkey         NVARCHAR(10)
         , @c_Userdef03       NVARCHAR(20)
         , @c_salesman        NVARCHAR(30)
         , @C_Phone1          NVARCHAR(18)
         , @C_Contact1        NVARCHAR(30)

         , @n_TTLQty          INT
         , @c_shippername     NVARCHAR(45)
         , @c_Sku             NVARCHAR(20)
         , @c_Size            NVARCHAR(5)
         , @c_PickLoc         NVARCHAR(10)
         , @n_NoOfLine        INT
         , @c_getOrdKey       NVARCHAR(10)

 SET @n_NoOfLine = 6
 SET @c_getOrdKey = ''                --(CS01)

 CREATE TABLE #PACKLIST58RDT
         ( C_Contact1      NVARCHAR(30) NULL
         , C_Address1      NVARCHAR(45) NULL
         , C_Phone1        NVARCHAR(18) NULL
         , C_Address2      NVARCHAR(45) NULL
         , M_Company       NVARCHAR(45) NULL
         , ExternOrderKey  NVARCHAR(30) NULL
         , PickLoc         NVARCHAR(10) NULL
         , C_State         NVARCHAR(45) NULL
         , ORDUdef01       NVARCHAR(20) NULL
         , PSku            NVARCHAR(20) NULL
         , PQty            INT
         , OrderKey        NVARCHAR(10) NULL
         , LoadKey         NVARCHAR(10) NULL
         , C_City          NVARCHAR(45) NULL
         , InvAmt          FLOAT  NULL
         , UnitPrice       FLOAT  NULL
         , SDescr          NVARCHAR(120) NULL
         , RecGrp          INT
         )

   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
              WHERE OrderKey = @c_Orderkey)
   BEGIN
      SET @c_getOrdKey = @c_Orderkey
   END
   ELSE
   BEGIN
      SELECT DISTINCT @c_getOrdKey = OrderKey
      FROM PackHeader AS ph WITH (NOLOCK)
      WHERE ph.PickSlipNo=@c_Orderkey
   END

   INSERT INTO #PACKLIST58RDT (
                       C_Contact1
                     , C_Address1
                     , C_Phone1
                     , C_Address2
                     , M_Company
                     , ExternOrderKey
                     , PickLoc
                     , C_State
                     , ORDUdef01
                     , PSku
                     , PQty
                     , OrderKey
                     , LoadKey
                     , C_City
                     , InvAmt
                     , UnitPrice
                     , SDescr
                     , RecGrp)
   SELECT ISNULL(OH.C_Contact1,''),ISNULL(OH.C_Address1,''),ISNULL(OH.C_Phone1,''),ISNULL(OH.C_Address2,''),
   ISNULL(OH.M_Company,''),OH.ExternOrderKey,PD.LOC,ISNULL(OH.C_State,''),
   ISNULL(OH.Userdefine01,''),PD.SKU,PD.qty,OH.OrderKey,
   OH.LoadKey,ISNULL(OH.C_City,''),OH.Invoiceamount,ORDDET.UnitPrice,s.descr,
   (Row_Number() OVER (PARTITION BY PD.OrderKey ORDER BY PD.LOC Asc)-1)/@n_NoOfLine
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OH.OrderKey
   AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey
   WHERE PD.OrderKey = @c_getOrdKey
   AND PD.CaseId = CASE WHEN ISNULL(@c_LabelNo,'') <> '' THEN @c_LabelNo ELSE PD.CaseId END
   ORDER By PD.LOC

   SELECT
        C_Contact1
      , C_Address1
      , C_Phone1
      , C_Address2
      , UPPER(M_Company)
      , ExternOrderKey
      , PickLoc
      , C_State
      , ORDUdef01
      , PSku
      , SUM(PQty) AS PQty 
      , OrderKey
      , LoadKey
      , C_City
      , InvAmt
      , UnitPrice
      , SDescr
      , RecGrp
   FROM #PACKLIST58RDT
   GROUP BY
        C_Contact1
      , C_Address1
      , C_Phone1
      , C_Address2
      , UPPER(M_Company)
      , ExternOrderKey
      , PickLoc
      , C_State
      , ORDUdef01
      , PSku
      , OrderKey
      , LoadKey
      , C_City
      , InvAmt
      , UnitPrice
      , SDescr
      , RecGrp
   ORDER BY PickLoc

END

GO