SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_print_pickorder_main                               */  
/* Creation Date: 25-Jul-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose:  WMS-17356                                                  */  
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
/************************************************************************/  
  
CREATE PROC [dbo].[isp_print_pickorder_main] (    
   @c_LOADKey NVARCHAR(21)       
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    
  
   SELECT DISTINCT LP.Loadkey AS loadkey,  
                   OH.type AS ohtype  
   FROM ORDERS OH WITH (NOLOCK)  
   INNER JOIN LOADPLAN LP WITH (NOLOCK) ON LP.LoadKey = OH.LoadKey    
   WHERE LP.Loadkey = @c_LOADKey  
   --GROUP BY MBOL.Mbolkey,ORDERS.type  
  
END -- procedure  

GO