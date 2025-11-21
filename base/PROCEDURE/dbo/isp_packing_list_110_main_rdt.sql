SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_110_main_rdt                           */
/* Creation Date: 16-Aug-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose:  WMS-17356                                                  */
/*        :                                                             */
/* Called By: r_dw_Packing_List_110_main_rdt                            */
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

CREATE PROC [dbo].[isp_Packing_List_110_main_rdt] (  
   @c_Pickslipno NVARCHAR(21) )   
 
AS   
BEGIN  
   SET NOCOUNT ON  
  -- SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  

   SELECT DISTINCT PH.PickSlipNo,
                   OH.Userdefine09 AS UDF09,
                   OH.type AS type,
                   OH.ShipperKey AS ShipKey
   FROM ORDERS OH WITH (NOLOCK)
   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = OH.OrderKey
   WHERE PH.Pickslipno = @c_Pickslipno
   GROUP BY PH.PickSlipNo,OH.Userdefine09,OH.type,OH.ShipperKey

END -- procedure

GO