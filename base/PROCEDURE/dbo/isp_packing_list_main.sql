SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_Packing_List_main                                   */  
/* Creation Date: 2022-06-08                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose:  WMS-19767                                                  */  
/*        :                                                             */  
/* Called By: r_dw_packing_list_main                                    */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */ 
/* 2022-06-08   MINGLE    1.0 Created(WMS-19767)                        */
/* 2022-06-08   MINGLE    1.0 DevOps Combine Script                     */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_main] (    
   @c_Pickslipno NVARCHAR(21)       
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    
  
    SELECT DISTINCT PH.PickSlipNo AS pickslipno,  
                    OH.type AS ordertype  
    FROM PACKHEADER      PH  WITH (NOLOCK)  
 JOIN ORDERS          OH  WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)  
 WHERE (PH.PickSlipNo = @c_Pickslipno )  
  
END -- procedure  

GO