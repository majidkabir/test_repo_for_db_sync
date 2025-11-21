SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_Packing_List_81                                */  
/* Creation Date: 28-AUG-2020                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:WMS-14913 -[CN] Natural Beauty Packing List by carton        */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_81                                      */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2021-10-26  Mingle   1.1   WMS-18235 - Modify logic(ML01)            */  
/* 2021-10-26  Mingle   1.1   DevOps Combine Script                     */  
/* 2021-12-30  SYChua   1.2   JSM-42945 - Fix missing qtyallocated(SY01)*/  
/* 2022-01-21  SYChua   1.3   JSM-47506 - Remove DISTINCT to fix missing*/  
/*                            orderdetail when sku and qty is the same  */  
/*                            (SY02)                                    */  
/*2023-OCT-20  CHONGCS  1.4   WMS-23788 add new sub report (CS01)       */
/************************************************************************/  
CREATE   PROC [dbo].[isp_packing_list_81_main]
         @c_PickSlipNo     NVARCHAR(10)  
        ,@c_type           NVARCHAR(5) = 'M'  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
  
         , @n_MaxCartonNo     INT  
         , @n_NoOfLine        INT  
         , @c_orderkey        NVARCHAR(20)  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_NoOfLine = 8  
  
  CREATE Table #TempPackList81 (  
                 Facility           NVARCHAR(50) NULL  
               , STR_Company        NVARCHAR(45) NULL  
               , ExternOrderkey     NVARCHAR(50) NULL  
               , Loadkey            NVARCHAR(10) NULL  
               , consigneekey       NVARCHAR(15) NULL  
             --  , SKU                NVARCHAR(20) NULL  
               , c_company          NVARCHAR(45) NULL  
               , c_address1         NVARCHAR(45) NULL  
               , c_address2         NVARCHAR(45) NULL  
               , c_address3         NVARCHAR(45) NULL  
               , c_address4         NVARCHAR(20) NULL  
               , InterModalVehicle  NVARCHAR(30) NULL  
               , PickSlipNo         NVARCHAR(10) NULL  
               , CartonNo           INT  
               , sku                NVARCHAR(20) NULL  
               , skudescr           NVARCHAR(60) NULL  
               , qty                INT  
               , unitprice          FLOAT  
               , Notes2_1           NVARCHAR(41) NULL  
               , Notes2_2           NVARCHAR(41) NULL  
               , Notes2_3           NVARCHAR(41) NULL  
               , Notes2_4           NVARCHAR(41) NULL  
               , Notes2_5           NVARCHAR(41) NULL  
               , sku_notes1         NVARCHAR(4000) NULL  
               , sku_busr5          NVARCHAR(30) NULL  
               , misspqty           NVARCHAR(5)  NULL  
               , c_zip              NVARCHAR(45) NULL  
               , Orderkey           NVARCHAR(20) NULL  
               , showsubrpt         NVARCHAR(5)  NULL  
    )  
  
   SET @n_MaxCartonNo = 0  
   SELECT TOP 1 @n_MaxCartonNo = PD.CartonNo  
   FROM PACKDETAIL PD WITH (NOLOCK)  
   WHERE PD.PickSlipNo = @c_PickSlipNo  
   ORDER BY PD.CartonNo DESC  
  
   INSERT INTO #TempPackList81 (  
              Facility  
               , STR_Company  
               , ExternOrderkey  
               , Loadkey  
               , consigneekey  
               , c_company  
               , c_address1  
               , c_address2  
               , c_address3  
               , c_address4  
               , InterModalVehicle  
               , PickSlipNo  
               , CartonNo  
               , sku  
               , skudescr  
               , qty  
               , unitprice  
               , Notes2_1  
               , Notes2_2  
               , Notes2_3  
               , Notes2_4  
               , Notes2_5  
               , sku_notes1  
               , sku_busr5  
               , misspqty  
               , c_zip  
               , Orderkey  
               , showsubrpt              )  
   SELECT Facility      = ISNULL(RTRIM(FACILITY.Descr),'')  
      ,STR_Company      = ISNULL(RTRIM(STORER.Company),'')  
      ,ExternOrderkey   = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
      ,Loadkey          = ISNULL(RTRIM(ORDERS.Loadkey),'')  
      ,ConsigneeKey     = ISNULL(RTRIM(ORDERS.ConsigneeKey),'')  
      ,C_Company        = ISNULL(RTRIM(ORDERS.C_Company),'')  
      ,C_Address1       = ISNULL(RTRIM(ORDERS.C_Address1),'')  
      ,C_Address2       = ISNULL(RTRIM(ORDERS.C_Address2),'')  
      ,C_Address3       = ISNULL(RTRIM(ORDERS.C_Address3),'')  
      ,C_Address4       = ISNULL(RTRIM(ORDERS.C_Address4),'')  
      ,InterModalVehicle= ISNULL(RTRIM(ORDERS.Shipperkey),'')  
      ,PickSlipNo       = ISNULL(PACKDETAIL.PickSlipNo,0)  
      ,CartonNo         = ISNULL(PACKDETAIL.CartonNo,0)  
      ,Sku              = ISNULL(RTRIM(PACKDETAIL.Sku),'')  
      ,SkuDescr         = ISNULL(RTRIM(SKU.Descr),'')  
      ,Qty              = ISNULL(SUM(PACKDETAIL.Qty),0)  
      ,UnitPrice        = CASE WHEN RTRIM(ISNULL(ORDERS.Userdefine01,'')) = 'N' THEN  
                               0  
                          ELSE  
                            (SELECT TOP 1 ISNULL(UnitPrice,0)  
                             FROM ORDERDETAIL WITH (NOLOCK)  
                             WHERE ORDERDETAIL.Orderkey = ISNULL(RTRIM(ORDERS.Orderkey),'')  
                             AND   ORDERDETAIL.Storerkey= ISNULL(RTRIM(PACKDETAIL.Storerkey),'')  
                             AND   ORDERDETAIL.Sku      = ISNULL(RTRIM(PACKDETAIL.Sku),''))  
                          END  
      ,Notes2_1           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),1,41)  
      ,Notes2_2           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),42,41)  
      ,Notes2_3           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),83,41)  
      ,Notes2_4           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),124,41)  
      ,Notes2_5           = SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),165,41)  
      ,sku_notes1         = ISNULL(SKU.notes1,'')  
      ,sku_busr5          = ISNULL(SKU.BUSR5,'')  
      ,MissPQty =  (SELECT CASE WHEN SUM(openqty) > SUM(qtypicked) then 'Y' ELSE 'N' END  
                             FROM ORDERDETAIL WITH (NOLOCK)  
                             WHERE ORDERDETAIL.Orderkey = ISNULL(RTRIM(ORDERS.Orderkey),''))  
                           --  AND   ORDERDETAIL.Storerkey= ISNULL(RTRIM(ORDERS.Storerkey),''))  
                            -- AND   ORDERDETAIL.Sku      = ISNULL(RTRIM(PACKDETAIL.Sku),''))  
     ,C_Zip               = ISNULL(RTRIM(ORDERS.C_Zip),'')  
     ,Orderkey   = ISNULL(RTRIM(ORDERS.Orderkey),'')  
     ,showsubrpt = 'N'  
   FROM PACKHEADER WITH (NOLOCK)  
   JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)  
   JOIN FACILITY   WITH (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)  
   JOIN STORER     WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)  
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
   JOIN SKU        WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)  
                                 AND(PACKDETAIL.Sku = SKU.Sku)  
   WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo  
   GROUP BY ISNULL(RTRIM(FACILITY.Descr),'')  
         ,  ISNULL(RTRIM(STORER.Company),'')  
         ,  ISNULL(RTRIM(ORDERS.Orderkey),'')  
         ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')  
         ,  ISNULL(RTRIM(ORDERS.Loadkey),'')  
         ,  ISNULL(RTRIM(ORDERS.ConsigneeKey),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Address2),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Address3),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Address4),'')  
         ,  ISNULL(RTRIM(ORDERS.Shipperkey),'')  
         ,  ISNULL(PACKDETAIL.PickSlipNo,0)  
         ,  ISNULL(PACKDETAIL.CartonNo,0)  
         ,  ISNULL(RTRIM(PACKDETAIL.Storerkey),'')  
         ,  ISNULL(RTRIM(PACKDETAIL.Sku),'')  
         ,  ISNULL(RTRIM(SKU.Descr),'')  
         ,  ORDERS.Userdefine01  
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),1,41)  
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),42,41)  
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),83,41)  
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),124,41)  
         ,  SUBSTRING(CONVERT(NVARCHAR(250), ORDERS.Notes2),165,41)  
         ,  ISNULL(SKU.notes1,'')  
         ,  ISNULL(SKU.BUSR5,'')  
         ,  ISNULL(RTRIM(ORDERS.Orderkey),'')  
         ,  ISNULL(RTRIM(ORDERS.C_Zip),'')  
    ORDER BY ISNULL(PACKDETAIL.CartonNo,0)  
         ,  ISNULL(RTRIM(PACKDETAIL.Sku),'')  
  
   IF EXISTS (SELECT 1 FROM #TempPackList81 WHERE MissPQty = 'Y')  
   BEGIN  
        UPDATE #TempPackList81  
        SET showsubrpt ='Y'  
        WHERE PickSlipNo = @c_PickSlipNo  
   END  
    IF @c_type = 'M' GOTO TYPE_M  
    IF @c_type = 'H' GOTO TYPE_H  
    IF @c_type = 'D' GOTO TYPE_D  
    IF @c_type = 'E' GOTO TYPE_E                 --CS01 
  
  TYPE_M:  
   SELECT DISTINCT  PickSlipNo  
                  , Orderkey  
                  , showsubrpt  
   FROM #TempPackList81  
  
  GOTO QUIT;  
  
   TYPE_H:  
   SELECT Facility  
               , STR_Company  
               , ExternOrderkey  
               , Loadkey  
               , consigneekey  
               , c_company  
               , c_address1  
               , c_address2  
               , c_address3  
               , c_address4  
               , InterModalVehicle  
               , PickSlipNo  
               , CartonNo  
               , sku  
               , skudescr  
               , qty  
               , unitprice  
               , Notes2_1  
               , Notes2_2  
               , Notes2_3  
               , Notes2_4  
               , Notes2_5  
               , sku_notes1  
               , sku_busr5  
               , misspqty  
               , c_zip  
               , Orderkey  
               , showsubrpt  
               , CAST((unitprice * qty) as decimal(10,2)) as qtyprice  
   FROM #TempPackList81  
   Order by cartonno,sku  
  
  --DROP TABLE #TEMPMNFTBLH06  
  GOTO QUIT;  
  
   TYPE_D:  
  
   SET @c_orderkey = ''  
   SELECT @c_orderkey = Orderkey  
   FROM #TempPackList81  
   Where Pickslipno = @c_pickslipno  
  
   --SELECT DISTINCT      --SY02  
   SELECT OD.Orderkey as Orderkey,     --SY02  
                   OD.sku as SKU,  
                   S.descr as descr,  
                   OD.OriginalQty as Originalqty  
                  , QtyPicked = OD.qtyallocated + OD.qtypicked --OD.QtyPicked     --SY01  
                  , UnitPrice = OD.UnitPrice  
                  ,QtyDiff = ( OD.qtyallocated + OD.qtypicked - od.originalqty ) --( od.qtypicked - od.originalqty )   --SY01  
                  ,qtyprice = CAST(OD.UnitPrice * ( od.qtypicked - od.originalqty )as decimal(10,2))  
   --FROM #TempPackList81 T81  
   --FULL JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = T81.ORderkey AND OD.sku = T81.sku  
  FROM ORDERDETAIL OD WITH (nolock)  
  JOIN SKU S WITH (NOLOCK) ON S.storerkey = OD.Storerkey AND S.sku = OD.sku  
  --LEFT OUTER JOIN #TempPackList81 T81 ON OD.OrderKey = T81.ORderkey AND OD.sku = T81.sku  
   WHERE OD.orderkey = @c_orderkey  
   AND ( od.qtyallocated+od.qtypicked - od.originalqty ) <> 0  --ML01  
   --AND T81.misspqty = 'Y'  
   Order by OD.Orderkey,OD.sku  

   --CS01 S
   TYPE_E:



   SELECT DISTINCT TP.PickSlipNo,TP.sku,TP.skudescr AS descr  ,SUM(PD.qty) AS qty,LOTT.Lottable02,CONVERT(NVARCHAR(10),LOTT.Lottable04,111) AS LOTT04,TP.Orderkey,TP.ExternOrderkey
   FROM #TempPackList81 TP
   JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey=TP.Orderkey AND PD.sku = TP.sku 
   JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.Lot = PD.Lot
   GROUP BY TP.PickSlipNo,TP.sku,TP.skudescr,LOTT.Lottable02,CONVERT(NVARCHAR(10),LOTT.Lottable04,111),TP.Orderkey,TP.ExternOrderkey
  --CS01 E
   GOTO QUIT;  
  
END -- procedure  
QUIT:

GO