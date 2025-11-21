SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_sum_speedo                         */
/* Creation Date: 17-JAN-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CHONG                                                    */
/*                                                                      */
/* Purpose:  WMS-16903 - [CN]Speedo_Carton Label for last carton_CR     */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_sum_speedo                          */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_sum_speedo]
           @c_PickSlipNo      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT
         
         , @n_PrintOrderAddresses   INT
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

    SELECT  
         MAX(PH.Loadkey) as loadkey,
         COUNT(DISTINCT PD.CartonNo) AS CartonNo,
         (SELECT SUM(qty) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo =  PH.pickslipno ) AS PackQty,  
         PRNDATE = CONVERT(NVARCHAR(10), GETDATE(), 101) + SPACE(1) + CONVERT(NVARCHAR(10), GETDATE(), 108)                                           
  FROM  PackDetail PD WITH (NOLOCK)
  JOIn PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo 
  JOIN ORDERS WITH (NOLOCK) ON Orders.loadkey = PH.loadkey     
  WHERE PD.PickSlipNo =@c_PickSlipNo 
  and PH.orderkey = ''and ph.loadkey <> ''
  group by  PH.pickslipno

QUIT_SP:
END -- procedure

GO