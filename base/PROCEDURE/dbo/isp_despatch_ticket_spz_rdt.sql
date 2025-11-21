SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Stored Procedure: isp_Despatch_Ticket_SPZ_RDT                        */  
/* Creation Date: 04-Nov-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15452 - SPZ Commercial Invoice                          */  
/*                                                                      */  
/* Called By: report dw = r_dw_Despatch_Ticket_SPZ_rdt                  */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 2023-01-03   mingle    1.1   WMS-21381 - Add oh.type(ML01)           */
/************************************************************************/  
CREATE   PROC [dbo].[isp_Despatch_Ticket_SPZ_RDT] (  
      @c_Pickslipno   NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_Orderkey      NVARCHAR(10)
   
   SET @c_Orderkey = @c_Pickslipno
   
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)
   BEGIN
      SELECT @c_Orderkey = OrderKey
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_Pickslipno
   END
   
   SELECT @c_Pickslipno AS Sourcekey
        , CASE WHEN TRIM(ISNULL(OH.DocType,'')) = ''
               THEN 'N'
               ELSE TRIM(ISNULL(OH.DocType,'')) END AS DocType
        , OH.[Type]	--ML01
   FROM ORDERS OH (NOLOCK)
   WHERE OH.OrderKey = @c_Orderkey

END

GO