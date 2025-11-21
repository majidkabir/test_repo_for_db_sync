SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_packing_list_101_main                               */  
/* Creation Date: 28-FEB-2022                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CHONGCS                                                  */  
/*                                                                      */  
/* Purpose: WMS-18985 CN_Converse_PackList_ByteDance_CR                 */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_101_main                                */  
/*          :                                                           */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 24-FEB-2022 CSCHONG  1.0   Devops Scripts Combine                    */  
/* 14-Jul-2022 WLChooi  1.1   WMS-20244 - Cater for B2B (WL01)          */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_packing_list_101_main] (    
   @c_Pickslipno NVARCHAR(21) )     
   
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    
  
  
 DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @n_NoOfLine        INT  
         , @c_Orderkey        NVARCHAR(20)  
         , @c_OHUDF03         NVARCHAR(50)  
         , @c_storerkey       NVARCHAR(20)  
         , @c_rpttype         NVARCHAR(20)  
         , @c_Channel         NVARCHAR(20) = ''   --WL01
         , @c_OHUDF02         NVARCHAR(30) = ''   --WL01
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_NoOfLine = 3  
   SET @c_Orderkey = ''  
  
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)  
              WHERE Orderkey = @c_PickSlipNo)  
   BEGIN  
      SET @c_Orderkey = @c_PickSlipNo  
   END  
   ELSE  
   BEGIN  
      SELECT DISTINCT @c_Orderkey = OrderKey  
      FROM PackHeader AS ph WITH (NOLOCK)  
      WHERE ph.PickSlipNo = @c_PickSlipNo  
   END  
  
   --WL01 S
   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Orderkey = LPD.OrderKey  
      FROM PACKHEADER PH (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
      WHERE PH.PickSlipNo = @c_PickSlipNo 
   END

   SELECT @c_Channel = ORDERDETAIL.Channel
   FROM ORDERDETAIL (NOLOCK)
   WHERE ORDERDETAIL.OrderKey = @c_Orderkey

   IF @c_Channel = 'B2B'
   BEGIN
      SET @c_rpttype = @c_Channel
   END
   ELSE
   BEGIN   --WL01 E
      SELECT  @c_OHUDF03   = OH.Userdefine03  
             ,@c_storerkey = OH.Storerkey
             ,@c_OHUDF02   = OH.UserDefine02   --WL03
      FROM ORDERS OH WITH (NOLOCK)  
      WHERE OH.Orderkey = @c_Orderkey  
      
      SELECT @c_rpttype = RTRIM(C.short)  
      FROM Codelkup  C WITH (nolock)  
      WHERE c.listname = 'CONVSTORE'  
      AND C.code = @c_OHUDF03  
      AND C.storerkey = @c_storerkey 
      
      IF @c_OHUDF02 = '1'
      BEGIN
         SET @c_rpttype = 'B2B'
      END
   END   --WL01
  
   SELECT @c_Pickslipno AS Pickslipno , @c_rpttype AS rprtype  
  
END -- procedure  

GO