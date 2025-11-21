SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_119_rdt                       */
/* Creation Date: 17-Jan-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21580 - CN_PUMA_CartonLabel_CR                          */
/*                                                                      */
/* Called By: r_dw_ucc_carton_label_119_rdt                             */
/*                                                                      */
/* Parameters: (Input)  @c_Storerkey      = Storerkey                   */
/*                      @c_Pickslipno     = Pickslipno                  */
/*                      @c_StartCartonNo  = CartonNoStart               */
/*                      @c_EndCartonNo    = CartonNoEnd                 */
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
CREATE   PROCEDURE [dbo].[isp_UCC_Carton_Label_119_rdt]
   @c_Storerkey     NVARCHAR(15)
 , @c_Pickslipno    NVARCHAR(10)
 , @c_StartCartonNo NVARCHAR(10)
 , @c_EndCartonNo   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1
         , @n_Err      INT
         , @c_Errmsg   NVARCHAR(250)

   SELECT PickSlipNo
        , LoadKey
        , CartonNo
        , Barcode
        , FromlabelLine = MIN(LabelLine)
        , TolabelLine = MAX(LabelLine)
   FROM (  SELECT PackHeader.PickSlipNo
                , PackHeader.LoadKey
                , PackDetail.CartonNo
                --, Barcode = CASE WHEN ISNULL(RTRIM(Orders.Consigneekey),'') BETWEEN '0003920001' AND '0003929999'  
                -- THEN 'W'+RTRIM(PACKHEADER.Loadkey)+RIGHT('00000' + RTRIM(CAST(PackDetail.CartonNo AS CHAR)),5) 
                -- ELSE 'O'+RTRIM(PACKHEADER.Loadkey)+RIGHT('00000' + RTRIM(CAST(PackDetail.CartonNo AS CHAR)),5) 
                --END   
                , Barcode = PackDetail.LabelNo
                , RowNumber = (ROW_NUMBER() OVER (PARTITION BY PackDetail.CartonNo
                                                  ORDER BY PackHeader.PickSlipNo
                                                         , PackDetail.CartonNo
                                                         , PackDetail.LabelLine ASC) - 1) / 28
                , PackDetail.LabelLine
           FROM PackHeader WITH (NOLOCK)
           JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLANDETAIL.LoadKey = PackHeader.LoadKey)
           JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = LOADPLANDETAIL.OrderKey)
           JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
           WHERE PackHeader.StorerKey = @c_Storerkey
           AND   PackHeader.PickSlipNo = @c_Pickslipno
           AND   PackDetail.CartonNo BETWEEN CAST(@c_StartCartonNo AS INT) AND CAST(@c_EndCartonNo AS INT)
           GROUP BY PackHeader.PickSlipNo
                  , PackHeader.LoadKey
                  , PackDetail.CartonNo
                  , PackDetail.LabelNo
                  --,  CASE WHEN ISNULL(RTRIM(Orders.Consigneekey),'') BETWEEN '0003920001' AND '0003929999'  
                  -- THEN 'W'+RTRIM(PACKHEADER.Loadkey)+RIGHT('00000' + RTRIM(CAST(PackDetail.CartonNo AS CHAR)),5) 
                  --ELSE 'O'+RTRIM(PACKHEADER.Loadkey)+RIGHT('00000' + RTRIM(CAST(PackDetail.CartonNo AS CHAR)),5) 
                  --END
                  , PackDetail.LabelLine) tmp
   GROUP BY PickSlipNo
          , LoadKey
          , CartonNo
          , Barcode
          , RowNumber
   ORDER BY PickSlipNo
          , LoadKey
          , CartonNo
END

GO