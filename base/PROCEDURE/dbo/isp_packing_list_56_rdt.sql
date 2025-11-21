SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure: isp_Packing_List_56_rdt                                   */
/* Creation Date: 29-AUG-2018                                                 */
/* Copyright: IDS                                                             */
/* Written by: CSCHONG                                                        */
/*                                                                            */
/* Purpose: WMS-5786 - CN Lululemon packing list RDT report                   */
/*                                                                            */
/*                                                                            */
/* Called By:  r_dw_packing_list_56_rdt                                       */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/* 22-MAR-2023  CSCHONG   1.1   Devops Scripts Combine & WMS-21998 (CS01)     */
/******************************************************************************/
CREATE   PROC [dbo].[isp_Packing_List_56_rdt]
       ( @c_Storerkey NVARCHAR(10),
         @c_Orderkey NVARCHAR(10))
        --@c_labelno  NVARCHAR(20))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_MCompany        NVARCHAR(45)
         , @c_Externorderkey  NVARCHAR(30)
         , @c_C_Addresses     NVARCHAR(200)
         , @c_loadkey         NVARCHAR(10)
         , @c_Userdef03       NVARCHAR(20)
         , @c_salesman        NVARCHAR(30)
         , @c_phone1          NVARCHAR(18)
         , @c_contact1        NVARCHAR(30)

         , @n_TTLQty          INT
         , @c_shippername     NVARCHAR(45)
         , @c_Sku             NVARCHAR(20)
         , @c_Size            NVARCHAR(5)
         , @c_PickLoc         NVARCHAR(10)
         , @c_getOrdKey       NVARCHAR(10)



     SET @c_getOrdKey = ''

 CREATE TABLE #PACKLIST56
         (c_Contact1      NVARCHAR(30) NULL
         , C_Addresses     NVARCHAR(250) NULL
         , OHDELNote       NVARCHAR(20) NULL
         , SDESCR          NVARCHAR(120) NULL
         , SBUSR7          NVARCHAR(30) NULL
         , MCompany        NVARCHAR(45) NULL
         , Externorderkey  NVARCHAR(30) NULL
         , PickLOC         NVARCHAR(10)  NULL
         , SCompany        NVARCHAR(45) NULL
         , SKUSize         NVARCHAR(10) NULL
         , CNote1          NVARCHAR(120) NULL
         , CNote2          NVARCHAR(120) NULL
         , SKU             NVARCHAR(20)  NULL
         , Udf03           NVARCHAR(30) NULL
         , OrderKey        NVARCHAR(10)  NULL
         , PQty            INT   DEFAULT(0)
         , Loadkey         NVARCHAR(20) NULL
         , Footerimage     NVARCHAR(100) NULL     --CS01
         )

  CREATE TABLE #TEMP_ORDERKEY56
  (
        ORDERKEY NVARCHAR(10) NOT NULL
  )

  IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
              WHERE Orderkey = @c_Orderkey)
  BEGIN
     INSERT INTO #TEMP_ORDERKEY56 (ORDERKEY)
  VALUES( @c_Orderkey)
  END
  ELSE IF EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK)
              WHERE PickDetail.PickSlipNo = @c_Orderkey)
  BEGIN
      INSERT INTO #TEMP_ORDERKEY56 (ORDERKEY)
      SELECT DISTINCT OrderKey
      FROM PickDetail AS PD WITH (NOLOCK)
      WHERE PD.PickSlipNo=@c_Orderkey
  END


     DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Orderkey
      FROM #TEMP_ORDERKEY56
      ORDER BY Orderkey

     OPEN CUR_ORDKEY

      FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey
      WHILE @@FETCH_STATUS = 0
      BEGIN

     INSERT INTO #PACKLIST56 (c_Contact1
                      , C_Addresses
                      , OHDELNote
                      , SDESCR
                      , SBUSR7
                      , MCompany
                      , Externorderkey
                      , PickLOC
                      , SCompany
                      , SKUSize
                      , CNote1
                      , CNote2
                      , SKU
                      , Udf03
                      , OrderKey
                      , PQty
                      , Loadkey,Footerimage )       --CS01
   SELECT ISNULL(OH.c_Contact1,''),(ISNULL(OH.c_city,'') + ISNULL(OH.C_address1,'')
        + ISNULL(OH.C_address2,'') + ISNULL(OH.C_address3,'') + ISNULL(OH.C_address4,'')),
          ISNULL(OH.Deliverynote,''),ISNULL(S.DESCR,''),ISNULL(S.BUSR7,''),
          OH.m_company ,
          OH.Externorderkey,ISNULL(PD.LOC,''),STO.company,s.size,ISNULL(c1.notes,''),ISNULL(c2.notes,''),
          PD.SKU,ISNULL(OH.Userdefine03,''),OH.Orderkey,PD.qty,OH.loadkey,ISNULL(c3.long,'')                     --CS01
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey AND PD.SKU = ORDDET.SKU AND pd.OrderLineNumber=ORDDET.OrderLineNumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.Storerkey=PD.Storerkey
   JOIN STORER STO WITH (NOLOCK) ON OH.Storerkey = STO.Storerkey
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.Listname = 'LULUPL' AND C1.Storerkey = OH.Storerkey AND C1.code='19'
   LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.Listname = 'LULUPL' AND C2.Storerkey = OH.Storerkey AND C2.code='20'
   LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.Listname = 'LLECPACK' AND C3.Storerkey = OH.Storerkey AND C3.code=OH.userdefine03           --CS01
   WHERE PD.Orderkey = @c_getOrdKey
   AND OH.storerkey = @c_Storerkey

   FETCH NEXT FROM CUR_ORDKEY INTO @c_getOrdKey
   END
   CLOSE CUR_ORDKEY
   DEALLOCATE CUR_ORDKEY



    SELECT DISTINCT   c_Contact1
               , C_Addresses
               , OHDELNote
               , SDESCR
               , SBUSR7
               , MCompany
               , Externorderkey
               , PickLOC
               , SCompany
               , SKUSize
               , CNote1
               , CNote2
               , SKU
               , Udf03
               , OrderKey
               , sum(PQty) as Pqty
               , Loadkey,Footerimage       --CS01
      FROM #PACKLIST56
      GROUP BY c_Contact1
          , C_Addresses
          , OHDELNote
          , SDESCR
          , SBUSR7
          , MCompany
          , Externorderkey
          , PickLOC
          , SCompany
          , SKUSize
          , CNote1
          , CNote2
          , SKU
          , Udf03
          , OrderKey
          , Loadkey
          ,Footerimage       --CS01
   ORDER BY PickLoc

END

GO