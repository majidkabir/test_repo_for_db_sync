SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note33_rdt                             */
/* Creation Date: 2018-10-04                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-8515 -[KR] Stussy Report Migration                       */
/*                                                                       */
/* Called By: r_dw_delivery_note33_rdt                                   */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*10/05/2019    WLCHOOI 1.0   WMS-9035 - Add ExternOrderkey and change   */
/*                                       mapping (WL01)                  */
/* 03/02/2021   CSCHONG 1.1  WMS-16223 revised field logic (CS01)        */
/* 05/08/2021   Mingle  1.2   WMS-17593 - Add new mappings(ML01)         */
/* 14/03/2022   Mingle  1.3   WMS-19027 - Add new mapping(ML02)          */
/* 14/03/2022   Mingle  1.3   DevOps Combine Script                      */
/*************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note33_rdt]
         (  @c_Orderkey    NVARCHAR(10)
         ,  @c_Loadkey     NVARCHAR(10)= ''
         ,  @c_Type        NVARCHAR(1) = ''
         )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_NoOfLine        INT
         , @n_TotDetail       INT
         , @n_LineNeed        INT
         , @n_SerialNo        INT
         , @b_debug           INT
         , @c_DelimiterSign   NVARCHAR(1)
         , @n_Count           int
         , @c_GetOrdkey       NVARCHAR(20)
         , @c_sku             NVARCHAR(20)
         , @c_ODUDF0102       NVARCHAR(120)
         , @n_seqno           INT
         , @c_ColValue        NVARCHAR(20)
         , @c_SStyle          NVARCHAR(50)
         , @c_SColor          NVARCHAR(50)
         , @c_SSize           NVARCHAR(50)
         , @n_maxLine         INT

   SET @n_NoOfLine = 10
   SET @n_TotDetail= 0
   SET @n_LineNeed = 0
   SET @n_SerialNo = 0
   SET @b_debug    = 0


      CREATE TABLE #TMP_ORD33
            (  SeqNo          INT IDENTITY (1,1)
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')
            ,  SKU            NVARCHAR(20) DEFAULT ('')
            ,  TotalQty       INT         DEFAULT (0)
            ,  RecGrp         INT         DEFAULT(0)

            )

      CREATE TABLE #TMP_HDR33
            (  SeqNo           INT
            ,  Orderkey        NVARCHAR(10) NULL
            ,  Storerkey       NVARCHAR(15) NULL
            ,  C_Cphone1       NVARCHAR(30) NULL
            ,  b_phone1        NVARCHAR(30) NULL
            ,  CAddress        NVARCHAR(180) NULL
            ,  SDescr          NVARCHAR(120) NULL
            ,  SKU             NVARCHAR(120) NULL
            ,  C_Zip           NVARCHAR(120) NULL
            ,  OrderDate       DATETIME NULL
            ,  Qty             INT  NULL
            ,  RecGrp          INT NULL
            ,  SBUSR2          NVARCHAR(50) NULL
            ,  C_Contact1      NVARCHAR(45) NULL
            ,  B_Contact1      NVARCHAR(45) NULL
            ,  MAddress        NVARCHAR(120) NULL
            ,  B_Zip           NVARCHAR(120) NULL
            ,  c_Country       NVARCHAR(45) NULL
            ,  b_Country       NVARCHAR(45) NULL
            ,  CNotes          NVARCHAR(120) NULL
            ,  BuyerPO         NVARCHAR(20) NULL
            ,  ExternOrderKey  NVARCHAR(50) NULL   --WL01
            ,  CNotes2         NVARCHAR(120) NULL  --ML01
            ,  CNotes3         NVARCHAR(120) NULL  --ML01
            ,  showfield       NVARCHAR(10) NULL   --ML01
            ,  CNotes4         NVARCHAR(120) NULL  --ML02
         )

      IF ISNULL(RTRIM(@c_Orderkey),'') = ''
      BEGIN

        INSERT INTO #TMP_ORD33
            (  Orderkey
            ,  SKU
            ,  TotalQty
            ,  RecGrp
            )
         SELECT DISTINCT OH.Orderkey
               ,OD.sku
               ,Sum(OD.originalqty)
              ,(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,OD.sku Asc)-1)/@n_NoOfLine + 1 AS recgrp
         FROM Orders OH  WITH (NOLOCK)
         JOIN OrderDetail OD (NOLOCK) ON OD.StorerKey = OH.StorerKey
                                      AND OD.Orderkey  = OH.OrderKey
         WHERE OH.Loadkey = @c_Loadkey
         GROUP BY OH.Orderkey ,OD.sku
       ORDER BY   OH.Orderkey ,OD.sku

      END
      ELSE
      BEGIN
          INSERT INTO #TMP_ORD33
            (  Orderkey
            ,  SKU
            ,  TotalQty
            ,  RecGrp
            )
         SELECT DISTINCT OH.Orderkey
               ,OD.sku
               ,Sum(OD.originalqty)
              ,(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,OD.sku Asc)-1)/@n_NoOfLine + 1 AS recgrp
         FROM Orders OH  WITH (NOLOCK)
         JOIN OrderDetail OD (NOLOCK) ON OD.StorerKey = OH.StorerKey
                                      AND OD.Orderkey  = OH.OrderKey
         WHERE OH.orderkey = @c_orderkey
         GROUP BY OH.Orderkey ,OD.sku
       ORDER BY   OH.Orderkey ,OD.sku
      END

      INSERT INTO #TMP_HDR33
            (  SeqNo
            ,  Orderkey
            ,  Storerkey
            ,  C_Cphone1
            ,  b_phone1
            ,  CAddress
            ,  SDescr
            ,  SKU
            ,  C_Zip
            ,  OrderDate
            ,  Qty
            ,  RecGrp
            ,  SBUSR2
            ,  C_Contact1
            ,  B_Contact1
            ,  MAddress
            ,  B_Zip
            ,  c_Country
            ,  b_Country
            ,  CNotes
            ,  BuyerPO
            ,  ExternOrderKey    --WL01
            ,  CNotes2           --ML01
            ,  CNotes3           --ML01
            ,  showfield         --ML01
            ,  CNotes4           --ML02
         )
      SELECT DISTINCT
             TMP.SeqNo
            ,OH.orderkey
            ,OH.Storerkey
            ,C_CPhone1      = 'T:' + OH.C_Phone1
            ,b_phone1       = 'T:' + OH.b_phone1
            ,Caddress       = (ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'')  )
            ,SDESCR         = S.descr
            --,SKU            = S.style + '-' + S.color + '-' + S.size --TMP.SKU
			,SKU            = CASE WHEN OH.Storerkey = 'SS' THEN S.RetailSku ELSE S.style + '-' + S.color + '-' + S.size END --ML02
            ,C_Zip          = (ISNULL(oh.c_city,'') + ISNULL(oh.c_State,'') +ISNULL(oh.c_Zip,'') )
            ,OrderDate      = ISNULL(RTRIM(OH.OrderDate),'')
            ,Qty            = TMP.TotalQty
            ,RecGrp         = TMP.Recgrp
            ,SBUSR2         = ISNULL(S.BUSR2,'')
            ,C_Contact1     = ISNULL(oh.c_contact1,'')
            ,B_Contact1     = ISNULL(OH.b_contact1,'')
            ,Maddress       = (ISNULL(OH.c_Address1,'') + ISNULL(OH.c_Address2,'')  )  --WL01
            ,B_Zip          = (ISNULL(OH.B_City,'') + ISNULL(OH.B_State,'') +ISNULL(OH.B_Zip,'') )
            ,c_Country      = OH.c_Country
            ,b_Country      = OH.b_Country
            ,CNotes         = ISNULL(MAX(CASE WHEN CL.Code ='1' THEN RTRIM(CL.notes) ELSE '' END),'')
            ,BuyerPO        = ISNULL(OH.BuyerPO,'')
         -- ,ExternOrderKey = ISNULL(OH.ExternOrderKey,'')     --WL01   --CS01
            ,ExternOrderkey = Case when ISNULL(OH.Userdefine02,'') = '' THEN ISNULL(OH.ExternOrderKey,'')     --CS01
                               Else  ISNULL(OH.Userdefine02,'') END
            ,CNotes2         = ISNULL(MAX(CASE WHEN CL2.Code ='2' THEN RTRIM(CL2.notes) ELSE '' END),'')      --ML01
            ,CNotes3         = ISNULL(MAX(CASE WHEN CL3.Code ='3' THEN RTRIM(CL3.notes) ELSE '' END),'')      --ML01
            ,showfield       = ISNULL(CL4.SHORT,'')
            ,CNotes4         = ISNULL(MAX(CASE WHEN CL5.Code ='4' THEN RTRIM(CL5.notes) ELSE '' END),'')      --ML01
      FROM #TMP_ORD33 TMP
      JOIN ORDERS      OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
      JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
                                        and OD.sku = TMP.sku
      JOIN SKU S WITH (NOLOCK) ON OD.storerkey = S.storerkey AND OD.sku = S.sku
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.listname = 'ssinv' And CL.storerkey = OH.Storerkey and CL.code='1'
      LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.listname = 'ssinv' And CL2.storerkey = OH.Storerkey and CL2.code='2' --ML01
      LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON CL3.listname = 'ssinv' And CL3.storerkey = OH.Storerkey and CL3.code='3' --ML01
      LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON CL4.listname = 'reportcfg' And CL4.storerkey = OH.Storerkey and CL4.long='r_dw_delivery_note33_rdt' --ML01
      LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON CL5.listname = 'ssinv' And CL5.storerkey = OH.Storerkey and CL5.code='4' --ML02
      GROUP BY   TMP.SeqNo
                 ,OH.orderkey
                 ,OH.Storerkey
                 ,OH.C_Phone1
                 ,OH.b_phone1
                 ,(ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'')  )
                 ,S.descr
                 ,S.style , S.color, S.size--TMP.SKU
                 ,(ISNULL(c_city,'') + ISNULL(c_State,'') +ISNULL(c_Zip,'') )
                 ,ISNULL(RTRIM(OH.OrderDate),'')
                 ,TMP.TotalQty
                 ,TMP.Recgrp
                 ,ISNULL(S.BUSR2,'')
                 ,ISNULL(c_contact1,'')
                 ,ISNULL(OH.b_contact1,'')
                 ,(ISNULL(OH.c_Address1,'') + ISNULL(OH.c_Address2,'')  )          --WL01
                 ,(ISNULL(OH.B_City,'') + ISNULL(OH.B_State,'') +ISNULL(OH.B_Zip,'') )
                 ,OH.c_Country
                 ,OH.b_Country
                 ,ISNULL(OH.BuyerPO,'')
                 --,ISNULL(MAX(CASE WHEN CL.Code ='C10' THEN RTRIM(CL.long) ELSE '' END),'')
                 --,ISNULL(OH.ExternOrderKey,'')   --WL01    --CS01
                   ,Case when ISNULL(OH.Userdefine02,'') = '' THEN ISNULL(OH.ExternOrderKey,'')
                               Else  ISNULL(OH.Userdefine02,'') END              --CS01
                   ,ISNULL(CL4.SHORT,'') --ML01
				   ,S.RetailSku --ML02
      ORDER BY TMP.SeqNo



      SELECT     SeqNo
            ,  Orderkey
            ,  Storerkey
            ,  C_Cphone1
            ,  b_phone1
            ,  CAddress
            ,  SDescr
            ,  SKU
            ,  C_Zip
            ,  OrderDate
            ,  Qty
            ,  RecGrp
            ,  SBUSR2
            ,  C_Contact1
            ,  B_Contact1
            ,  MAddress
            ,  B_Zip
            ,  c_Country
            ,  b_Country
            ,  CNotes
            ,  BuyerPO
            ,  ExternOrderKey   --WL01
            ,  CNotes2          --ML01
            ,  CNotes3          --ML01
            ,  showfield        --ML01
            ,  CNotes4          --ML02
      FROM #TMP_HDR33
      ORDER BY SeqNo


      DROP TABLE #TMP_HDR33
      GOTO QUIT_SP


QUIT_SP:
END


GO