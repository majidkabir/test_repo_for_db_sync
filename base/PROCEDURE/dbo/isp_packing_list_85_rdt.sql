SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* StoredProc: isp_Packing_List_85_rdt                                  */  
/* Creation Date: 02-OCT-2020                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:                                                             */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_85_rdt                                  */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_Packing_List_85_rdt] (    
   @c_Pickslipno NVARCHAR(10)    
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   
  
  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   IF LEFT(@c_Pickslipno,1) = 'P' -- Print from ECOM Packing  
   BEGIN  
      SELECT @c_Pickslipno = Orderkey  
      FROM PICKHEADER WITH (NOLOCK)  
      WHERE PickHeaderKey = @c_Pickslipno   
   END  
    
   SELECT ORDERS.Orderkey,   
          ORDERS.ExternOrderKey,  
          CASE WHEN ORDERS.Shipperkey = 'SF'   
               THEN N'顺丰快递'   
               WHEN ORDERS.Shipperkey = 'EMS'     
               THEN 'EMS'    
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
          CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店',N'JORDAN天猫官方旗舰店')   
               THEN  N'请联系天猫旺旺客服，谢谢！'  
               ELSE  N'江苏省苏州市吴江区汾湖开发区来秀路888号欧圣电器南门宝尊电商3号Nike仓'  
          END AS ReturnAddress,  
          CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店',N'JORDAN天猫官方旗舰店')  
               THEN  N'请联系天猫旺旺客服，谢谢！'  
               ELSE  N'400-800-6453（手机），800-820-8865（固话）'  
          END AS ReturnContact,  
          CASE WHEN (SELECT SUM(PD.Qty) AS Qty   
                     FROM PICKDETAIL PD (NOLOCK)   
                     WHERE PD.Orderkey = ORDERS.Orderkey) = 1   
               THEN 'SINGLE_ORD'   
               ELSE ORDERS.Orderkey   
               END AS ETtype  
         ,PACKTASK.TaskBatchNo                                                    
         ,LogicalName = CASE WHEN ISNULL(RTRIM(PACKTASK.DevicePosition),'')= ''   
                             THEN ISNULL(RTRIM(PACKTASK.LogicalName),'')          
                             ELSE ISNULL(RTRIM(PACKTASK.DevicePosition),'')       
                             END  

         ,FUDF12 =  ISNULL(F.Userdefine12,'') 
         ,RTNTRACKNO = ISNULL(ORDERS.RTNTrackingno,'')    
         ,OHNotes2 = ISNULL(ORDERS.Notes2,'')                                            
   FROM ORDERS (NOLOCK)   
   JOIN PICKDETAIL (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey)  
   JOIN SKU  (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)  
   LEFT JOIN PACKTASK WITH (NOLOCK) ON (ORDERS.Orderkey = PACKTASK.Orderkey)  
   JOIN FACILITY F WITH (NOLOCK) ON F.facility = ORDERS.Facility   
   WHERE ORDERS.Orderkey = @c_Pickslipno  
   --AND  ( PICKDETAIL.CaseID = @c_LabelNo OR ISNULL(@c_LabelNo,'') = '' )  
   AND ORDERS.doctype='E' AND ORDERS.facility='NSH04'
   AND ISNULL(ORDERS.RTNTrackingno,'') <> '' 
   GROUP BY ORDERS.Orderkey,   
            ORDERS.ExternOrderKey,  
            CASE WHEN ORDERS.Shipperkey = 'SF'   
                 THEN N'顺丰快递'   
                 WHEN ORDERS.Shipperkey = 'EMS'    
                 THEN 'EMS'    
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
             CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店' ,N'JORDAN天猫官方旗舰店')  
                  THEN  N'请联系天猫旺旺客服，谢谢！'  
                  ELSE  N'江苏省苏州市吴江区汾湖开发区来秀路888号欧圣电器南门宝尊电商3号Nike仓'  
             END ,  
             CASE WHEN ORDERS.Userdefine03 IN (N'Nike官方旗舰店' ,N'JORDAN天猫官方旗舰店')  
                  THEN  N'请联系天猫旺旺客服，谢谢！'  
                  ELSE  N'400-800-6453（手机），800-820-8865（固话）'  
             END    
         ,PACKTASK.TaskBatchNo                                                    
         ,ISNULL(RTRIM(PACKTASK.DevicePosition),'')                               
         ,ISNULL(RTRIM(PACKTASK.LogicalName),'')    
         ,ISNULL(F.Userdefine12,'')  
         ,ISNULL(ORDERS.RTNTrackingno,'')                                       
         ,ISNULL(ORDERS.Notes2,'')   
   ORDER BY PACKTASK.TaskBatchNo         
         ,  CASE WHEN ISNULL(RTRIM(PACKTASK.DevicePosition),'')= ''     
                             THEN ISNULL(RTRIM(PACKTASK.LogicalName),'')            
                             ELSE ISNULL(RTRIM(PACKTASK.DevicePosition),'')        
                             END      
         ,  ETtype   
         ,  ORDERS.Orderkey   
         ,  Loc  
         ,  PICKDETAIL.Sku   
QUIT_SP:  
      WHILE @@TRANCOUNT < @n_StartTCnt  
      BEGIN  
         BEGIN TRAN  
      END  
END -- procedure  


GO