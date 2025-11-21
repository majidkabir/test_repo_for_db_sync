SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_103_sg_main                            */
/* Creation Date: 03-AUG-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose:  WMS-17356                                                  */
/*        :                                                             */
/* Called By: r_dw_packing_list_sg_main                                 */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 13-JAN-2022  CSCHONG   1.0 Devops Scripts Combine                    */
/* 13-JAN-2022  CSCHONG   1.1 WMS-17744 Change print logic based on     */  
/*                              Orders.SpecialHandling (CS01)           */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_103_sg_main] (  
   @c_MBOLKey  NVARCHAR(21)   
  ,@c_type     NVARCHAR(10)   = ''
  ,@c_ShipType NVARCHAR(10)   = ''  
  ,@c_SHPFlag  NVARCHAR(10)   = ''     --CS01 
)   
AS   
BEGIN  
   SET NOCOUNT ON  
  -- SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  

   SELECT DISTINCT MBOL.Mbolkey AS mbolkey,
                   Shiptype = @c_ShipType,
                   ORDERS.type AS ordertype,
                   SHPFlag = @c_SHPFlag               --CS01
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)  
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   WHERE MBOL.Mbolkey = @c_mbolkey
   GROUP BY MBOL.Mbolkey,ORDERS.type

END -- procedure

GO