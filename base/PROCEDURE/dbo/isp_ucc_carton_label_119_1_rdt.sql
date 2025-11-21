SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_119_1_rdt                     */
/* Creation Date: 17-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21580 - CN_PUMA_CartonLabel_CR                          */
/*                                                                      */
/* Called By: r_dw_ucc_carton_label_119_rdt                             */
/*                                                                      */
/* Parameters: (Input)  @c_Pickslipno     = Pickslipno                  */
/*                      @c_CartonNo       = CartonNo                    */
/*                      @c_LabelLine      = StartLabelLine              */
/*                      @c_EndCartonNo    = EndLabelLine                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 17-Jan-2023  WLChooi   1.0  DevOps Combine Script                    */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_UCC_Carton_Label_119_1_rdt]
   @c_Pickslipno     NVARCHAR(15)
 , @c_CartonNo       NVARCHAR(10)
 , @c_StartLabelLine NVARCHAR(5)
 , @c_EndLabelLine   NVARCHAR(5)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1
         , @n_Err      INT
         , @c_Errmsg   NVARCHAR(250)

   SELECT DISTINCT PackHeader.PickSlipNo
                 , PackDetail.CartonNo
                 , PackDetail.SKU
                 , SKU.Size
                 , PackDetail.Qty
   FROM PACKHEADER WITH (NOLOCK)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LoadPlanDetail.LoadKey = PACKHEADER.LoadKey)
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = LoadPlanDetail.OrderKey)
   JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
   JOIN SKU WITH (NOLOCK) ON (PackDetail.SKU = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey)
   JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
   WHERE PackHeader.PickSlipNo = @c_Pickslipno
   AND   PackDetail.CartonNo = @c_CartonNo
   AND   PackDetail.LabelLine >= @c_StartLabelLine
   AND   PackDetail.LabelLine <= @c_EndLabelLine
END

GO