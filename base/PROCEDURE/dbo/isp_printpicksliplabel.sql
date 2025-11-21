SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_printpicksliplabel                              */  
/* Creation Date: 13-APR-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#239665: Dynamic Barcode Label for Pickslip from Report   */  
/*                      Module.                                          */
/*                                                                       */  
/* Called By: Call from Report Module - PUMA01 (IDSTW)                   */
/*                      Wave - Show Allocation Summary                   */  
/*            datawindow: r_dw_pickslip_label                            */
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  

CREATE PROC [dbo].[isp_printpicksliplabel]
      @c_LoadKey     NVARCHAR(10)
   ,  @c_PickSlipNo  NVARCHAR(10) 
   ,  @c_OrderkeyFr  NVARCHAR(10)
   ,  @c_OrderkeyTo  NVARCHAR(10)
   ,  @n_Cartons     INT
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Cnt       INT
         , @n_RowCnt    INT
         , @c_LabelNo   NVARCHAR(15)

   SET @n_Cnt     = 1 
   SET @n_RowCnt  = 0
   SET @c_LabelNo = ''
      
   CREATE TABLE ##PickSlipLabel 
      (
         LabelNo  NVARCHAR(15)    NOT NULL DEFAULT ('')
      )

   IF RTRIM(@c_OrderkeyFr) = '' AND RTRIM(@c_OrderkeyTo) <> '' SET @c_OrderkeyTo = ''
   IF RTRIM(@c_OrderkeyFr) <> '' AND RTRIM(@c_OrderkeyTo) = '' SET @c_OrderkeyTo = @c_OrderkeyFr
   IF RTRIM(@c_LoadKey) = '' AND RTRIM(@c_PickSlipNo) = '' AND RTRIM(@c_OrderkeyFr) = '' AND RTRIM(@c_OrderkeyTo) = '' GOTO QUIT 
   IF @n_Cartons = 0 GOTO QUIT
   
   DECLARE C_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PICKHEADER.PickHeaderKey
   FROM PICKHEADER WITH (NOLOCK)
   JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.Orderkey = ORDERS.Orderkey)
   WHERE PICKHEADER.PickHeaderkey = CASE WHEN ISNULL(RTRIM(@c_PickSlipNo),'') = '' THEN PICKHEADER.PickHeaderkey ELSE @c_PickSlipNo END
   AND   ORDERS.Orderkey BETWEEN CASE WHEN ISNULL(RTRIM(@c_OrderkeyFr),'') = '' 
                                      THEN ORDERS.Orderkey ELSE @c_OrderkeyFr END  
                         AND     CASE WHEN ISNULL(RTRIM(@c_OrderkeyTo),'') = ''
                                      THEN ORDERS.Orderkey ELSE @c_OrderkeyTo END 
   AND   ORDERS.Loadkey = CASE WHEN ISNULL(RTRIM(@c_Loadkey),'') = '' THEN ORDERS.Loadkey ELSE @c_Loadkey END
   ORDER BY PICKHEADER.PickHeaderKey

   OPEN C_PickSlip
      
   FETCH NEXT FROM C_PickSlip INTO @c_PickSlipNo 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Cnt = 1
      WHILE @n_Cnt <= @n_Cartons
      BEGIN
         SET @c_LabelNo = @c_PickSlipNo + CONVERT(NVARCHAR(1000),@n_Cnt)
         
         INSERT INTO ##PickSlipLabel (LabelNo)
         VALUES (@c_LabelNo)

         SET @n_Cnt = @n_Cnt + 1
      END
      FETCH NEXT FROM C_PickSlip INTO @c_PickSlipNo 
   END
   CLOSE C_PickSlip
   DEALLOCATE C_PickSlip 

   QUIT:
   SELECT LabelNo
   FROM ##PickSlipLabel

   DROP TABLE ##PickSlipLabel
END

GO