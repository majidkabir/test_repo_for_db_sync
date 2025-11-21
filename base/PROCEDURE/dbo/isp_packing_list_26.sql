SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* StoredProc: isp_Packing_List_26                                      */
/* Creation Date: 21-AUG-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-2730 - [CR]CN NIKE ECOM Pack List                       */
/*        : Change to use SP                                            */
/* Called By: r_dw_packing_list_26                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 6-Nov-2017  Wendy    1.0   Change for double 11(WWANG01)             */
/* 6-SEP-2019  CSCHONG  1.1   WMS-10413 revised sorting rule (CS01)     */
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_26] 
            @c_PickSlipNo  NVARCHAR(10)
         ,  @c_Orderkey    NVARCHAR(10)
         ,  @c_Loadkey     NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         
         , @c_SQL             NVARCHAR(4000)
         , @c_SQLArgument     NVARCHAR(4000)

   SET @n_StartTCnt = @@TRANCOUNT

   CREATE TABLE #TMP_PACKORDER 
   ( Orderkey  NVARCHAR(10)   NOT NULL PRIMARY KEY)

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_SQL = N'SELECT DISTINCT OH.Orderkey'
              + ' FROM ORDERS OH WITH (NOLOCK)'
              + ' LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)'
              + ' WHERE 1=1'
              + CASE WHEN ISNULL(RTRIM(@c_PickSlipNo),'') = '' THEN '' ELSE ' AND PH.PickHeaderKey = @c_PickSlipNo' END
              + CASE WHEN ISNULL(RTRIM(@c_Orderkey),'') = '' THEN '' ELSE ' AND OH.Orderkey = @c_Orderkey' END
              + CASE WHEN ISNULL(RTRIM(@c_Loadkey),'') = '' THEN '' ELSE ' AND OH.Loadkey = @c_Loadkey'    END

   SET @c_SQLArgument = N'@c_PickSlipNo NVARCHAR(10)'
                      + ',@c_Orderkey   NVARCHAR(10)'
                      + ',@c_Loadkey    NVARCHAR(10)'

   INSERT INTO #TMP_PACKORDER ( Orderkey )
   EXEC sp_executesql  @c_SQL 
                     , @c_SQLArgument
                     , @c_PickSlipNo
                     , @c_Orderkey 
                     , @c_Loadkey   
  
QUIT_SP:
   SELECT ORDERS.Orderkey, 
         ORDERS.ExternOrderKey,
         CASE WHEN ORDERS.Shipperkey = 'SF' THEN
                     N'顺丰快递' 
                  WHEN ORDERS.Shipperkey = 'EMS' THEN 
                     'EMS'  
         END AS Shipper,
         ORDERS.C_Contact1, 
         ORDERS.C_Phone1,
         ORDERS.C_Zip,
         ORDERS.M_Company,
         ISNULL(ORDERS.C_Address1,'') AS C_Address1,
         ISNULL(ORDERS.C_Address2,'') AS C_Address2,
         ISNULL(ORDERS.C_Address3,'') AS C_Address3,
         ISNULL(ORDERS.C_Address4,'') AS C_Address4,
         ISNULL(ORDERS.C_City,'') AS C_City,
         ISNULL(ORDERS.C_State,'') AS C_State,
         PICKDETAIL.Sku,
         SKU.Descr, 
         SUBSTRING(PICKDETAIL.Loc, 1, 3) + '-' + SUBSTRING(PICKDETAIL.Loc, 4, 3) + '-' + SUBSTRING(PICKDETAIL.Loc, 7, 2) + '-' + SUBSTRING(PICKDETAIL.Loc, 9, 1) + '-' + SUBSTRING(PICKDETAIL.Loc, 10, 1) AS Loc,
         SUM(PICKDETAIL.Qty) AS Qty,
         CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店',N'JORDAN天猫官方旗舰店') THEN  --WWANG01
                        N'请联系天猫旺旺客服，谢谢！'
                  ELSE
                        N'江苏省苏州市吴江区汾湖开发区来秀路888号欧圣电器南门宝尊电商3号Nike仓'
         END AS ReturnAddress,
         CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店',N'JORDAN天猫官方旗舰店') THEN  --WWANG01
                        N'请联系天猫旺旺客服，谢谢！'
                  ELSE
                        N'400-800-6453（手机），800-820-8865（固话）'
         END AS ReturnContact,
         CASE WHEN ( SELECT SUM(PD.Qty) AS Qty 
                     FROM PICKDETAIL PD (NOLOCK) 
                     WHERE PD.Orderkey = ORDERS.Orderkey) = 1 THEN 'SINGLE_ORD' ELSE ORDERS.Orderkey END AS ETtype
         ,PACKTASK.TaskBatchNo                                                   
         ,LogicalName = CASE WHEN ISNULL(RTRIM(PACKTASK.DevicePosition),'')= ''   
                             THEN ISNULL(RTRIM(PACKTASK.LogicalName),'')          
                             ELSE ISNULL(RTRIM(PACKTASK.DevicePosition),'')      
                             END                                               
   FROM #TMP_PACKORDER
   JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = #TMP_PACKORDER.Orderkey)
   JOIN PICKDETAIL (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey)
   JOIN SKU  (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
   LEFT JOIN PACKTASK WITH (NOLOCK) ON (ORDERS.Orderkey = PACKTASK.Orderkey) 
   GROUP BY ORDERS.Orderkey, 
            ORDERS.ExternOrderKey,
            CASE WHEN ORDERS.Shipperkey = 'SF' THEN
                       N'顺丰快递' 
                  WHEN ORDERS.Shipperkey = 'EMS' THEN 
                          'EMS'  
            END,
            ORDERS.C_Contact1, 
            ORDERS.C_Phone1,
            ORDERS.C_Zip,
            ORDERS.M_Company,
            ISNULL(ORDERS.C_Address1,''),
            ISNULL(ORDERS.C_Address2,''),
            ISNULL(ORDERS.C_Address3,''),
            ISNULL(ORDERS.C_Address4,''),
            ISNULL(ORDERS.C_City,''),
            ISNULL(ORDERS.C_State,''),
            PICKDETAIL.Sku,
            SKU.Descr,
            SUBSTRING(PICKDETAIL.Loc, 1, 3) + '-' + SUBSTRING(PICKDETAIL.Loc, 4, 3) + '-' + SUBSTRING(PICKDETAIL.Loc, 7, 2) + '-' + SUBSTRING(PICKDETAIL.Loc, 9, 1) + '-' + SUBSTRING(PICKDETAIL.Loc, 10, 1),
            CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店','JORDAN天猫官方旗舰店') THEN  --WWANG01
                   N'请联系天猫旺旺客服，谢谢！'
            ELSE
                   N'江苏省苏州市吴江区汾湖开发区来秀路888号欧圣电器南门宝尊电商3号Nike仓'
            END,
            CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店','JORDAN天猫官方旗舰店') THEN  --WWANG01
                   N'请联系天猫旺旺客服，谢谢！'
            ELSE
                   N'400-800-6453（手机），800-820-8865（固话）'
            END
         ,  PACKTASK.TaskBatchNo                                                   
         ,  ISNULL(RTRIM(PACKTASK.DevicePosition),'')                              
         ,  ISNULL(RTRIM(PACKTASK.LogicalName),'')        
		 ,  ORDERS.Userdefine03                        
   ORDER BY PACKTASK.TaskBatchNo          --CS01  START
         ,  CASE WHEN ISNULL(RTRIM(PACKTASK.DevicePosition),'')= ''   
                             THEN ISNULL(RTRIM(PACKTASK.LogicalName),'')          
                             ELSE ISNULL(RTRIM(PACKTASK.DevicePosition),'')      
                             END      --CS01 END
         ,  ETtype
         ,  ORDERS.Orderkey
         ,  Loc
         ,  PICKDETAIL.Sku 

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO