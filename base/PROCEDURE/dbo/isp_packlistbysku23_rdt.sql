SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackListBySku23_rdt                                 */
/* Creation Date: 21-MAR-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-19138 - CN Loreal Packing list_NEW                      */
/*        :                                                             */
/* Called By: r_dw_packing_list_By_Sku23_rdt                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver   Purposes                                 */
/* 21-MAR-2022  CHONGCS  1.0   Devops Scripts Comnbine                  */
/* 24-MAY-2022  MINGLE   1.1   Add new logic(ML01)                      */
/************************************************************************/
CREATE   PROC [dbo].[isp_PackListBySku23_rdt]
           @c_PickSlipNo      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt       INT
         , @n_Continue        INT
         , @n_MaxLineno       INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @n_Maxrecgrp       INT
		 , @c_Orderkey        NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT

   SET @n_MaxLineno = 10   

   --IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Pickslipno)
   --BEGIN
   --	  SELECT @c_Pickslipno = Pickheaderkey
   --	  FROM PICKHEADER (NOLOCK)
   --	  WHERE OrderKey = @c_Pickslipno
   --END

   --IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Pickslipno)
   --BEGIN
   --	  SELECT @c_Pickslipno = Orderkey
   --	  FROM ORDERS (NOLOCK)
   --	  WHERE OrderKey = @c_Pickslipno
   --END

   SET @c_Orderkey = @c_Pickslipno  
  
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)  
   BEGIN  
      SELECT @c_Orderkey = OrderKey  
      FROM PACKHEADER (NOLOCK)  
      WHERE PickSlipNo = @c_Pickslipno  
   END  

  CREATE TABLE #TMP_PICKLISTBYSKU23RDT (
    ExternOrderkey        NVARCHAR(50),
    ORDDate               DATETIME,
    SortBy                INT,
    RowNo                 INT,
    PickSlipNo            NVARCHAR(20),
    loadkey               NVARCHAR(20),
    ohudf03               NVARCHAR(20),
    SKU                   NVARCHAR(20),
    SDescr                NVARCHAR(80),
    st_BAdd3              NVARCHAR(45),
    st_notes1             NVARCHAR(4000),
    st_BAdd4              NVARCHAR(45),
    qty                   INT,
    Storerkey             NVARCHAR(20),
    Orderkey              NVARCHAR(20),
    recgrp                INT NULL,
    Contact               NVARCHAR(45),
    Altsku                NVARCHAR(20),
	DevicePosition        NVARCHAR(10)
  )
  
INSERT INTO #TMP_PICKLISTBYSKU23RDT
(
    ExternOrderkey,
    ORDDate,
    SortBy,
    RowNo,
    PickSlipNo,
    loadkey,
    ohudf03,
    SKU,
    SDescr,
    st_BAdd3,
    st_notes1,
    st_BAdd4,
    qty,
    Storerkey,
    Orderkey,
    recgrp,
    Contact,
    Altsku,
	DevicePosition
)

   SELECT  ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')
         , ORDDate = OH.OrderDate
         , SortBy = ROW_NUMBER() OVER ( ORDER BY PH.PickSlipNo
                                                ,OH.Storerkey
                                                ,OH.Orderkey
                                                ,RTRIM(PD.sku)
                                     )
         , RowNo  = ROW_NUMBER() OVER ( PARTITION BY PH.PickSlipNo,OH.Loadkey
                                        ORDER BY PH.PickSlipNo
                                                ,OH.Storerkey
                                                ,OH.Orderkey
                                                ,RTRIM(PD.sku)
                                      )
  --       , PrintTime      = GETDATE()
         , PH.PickSlipNo
         , OH.Loadkey
         , OHUDF03 = ISNULL(RTRIM(OH.UserDefine03),'')
         , SKU= RTRIM(PD.sku)
         , SDescr= ISNULL(RTRIM(s.descr),'')
         , st_BAdd3  = ISNULL(RTRIM(ST.B_Address3),'')
         , ODNotst_notes1es2 = ISNULL(RTRIM(ST.notes1),'')
         , st_BAdd4  = ISNULL(RTRIM(ST.B_Address4),'')
         , Qty = ISNULL(SUM(PD.Qty),0)
         , OH.Storerkey
         , OH.Orderkey
         --, Recgrp = ROW_NUMBER() OVER ( PARTITION BY PH.PickSlipNo,ISNULL(RTRIM(ST.Company),'')
         --                               ORDER BY PH.PickSlipNo
         --                                       ,OH.Storerkey
         --                                       ,OH.Orderkey
         --                                       ,RTRIM(PD.sku)
         --                             )/(@n_MaxLineno+1)
         ,Recgrp = 1
         ,Contact = '***'
         ,S.ALTSKU
		 ,ISNULL(PT.DevicePosition,'')
   FROM ORDERS OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = OH.StorerKey AND S.SKU = OD.SKU
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND
                               PD.Sku = OD.Sku
   LEFT JOIN PACKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey
   LEFT JOIN dbo.STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey -- AND ST.type='2'
   LEFT JOIN PACKTASK PT(NOLOCK) ON PT.Orderkey = OH.OrderKey
   WHERE OH.Orderkey = @c_Orderkey
   GROUP BY PH.PickSlipNo
         ,  OH.Storerkey
         ,  OH.Loadkey
         ,  OH.Orderkey
         ,  ISNULL(RTRIM(OH.UserDefine03),'')
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,  OH.OrderDate
         ,  RTRIM(PD.sku)
         ,  ISNULL(RTRIM(s.descr),'')
         ,  ISNULL(RTRIM(ST.B_Address3),'')
         ,  ISNULL(RTRIM(ST.B_Address4),'')
         ,  ISNULL(RTRIM(ST.notes1),'')
         ,  S.ALTSKU
		 ,  ISNULL(PT.DevicePosition,'')

    SET @n_Maxrecgrp = 1
    SET @n_MaxRec = 1

     SELECT ExternOrderkey,
             ORDDate,
             SortBy,
             RowNo,
             PickSlipNo,
             loadkey,
             ohudf03,
             SKU,
             SDescr,
             st_BAdd3,
             st_notes1,
             st_BAdd4,
             qty,
             Storerkey,
             Orderkey,
             recgrp,
             Contact,
             Altsku,
			 DevicePosition
   FROM #TMP_PICKLISTBYSKU23RDT
   ORDER BY PickSlipNo,Orderkey,sku

END -- procedure

GO