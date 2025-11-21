SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_ucc_carton_label_51_1                               */  
/* Creation Date: 17-OCT-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:  WMS-10879 - Convert to call SP                             */  
/*        :                                                             */  
/* Called By: r_dw_ucc_carton_label_51_1                                */  
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
CREATE PROC [dbo].[isp_ucc_carton_label_51_1]    
     @c_PickSlipNo        NVARCHAR(10),
     @c_CartonNo          NVARCHAR(5)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt             INT  
         , @n_Continue              INT
         , @c_Storerkey             NVARCHAR(15) 
         
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  

   SELECT TOP 1 @c_Storerkey = Storerkey
   FROM PACKHEADER (NOLOCK)
   WHERE Pickslipno = @c_PickSlipNo

   CREATE TABLE #Temp_Size(
   rowid INT NOT NULL IDENTITY(1,1),
   SIZE  NVARCHAR(20) )

   INSERT INTO #Temp_Size
   SELECT Short
   FROM CODELKUP (NOLOCK)
   WHERE Listname = 'XTEPSZST' AND Storerkey = @c_Storerkey
   ORDER BY CAST(Code AS INT)

   --SELECT * FROM #Temp_Size
   CREATE TABLE #Temp_51_1(
   CartonNo   INT,
   Style      NVARCHAR(20),
   BUSR6      NVARCHAR(20),
   Size       NVARCHAR(20),
   Qty        INT )
   
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      INSERT INTO #Temp_51_1
      SELECT PackDetail.CartonNo
           , SKU.Style
           , ISNULL(SKU.BUSR6,'')
           , CASE WHEN ISNULL(C.short,'')='Y' THEN 
             CASE WHEN sku.measurement IN ('','U') THEN SKU.BUSR7 ELSE ISNULL(sku.measurement,'') END
             ELSE SKU.SIZE END [Size]
	  	     , PackDetail.Qty
      FROM PackDetail WITH (NOLOCK) 
      JOIN SKU WITH (NOLOCK) ON (Sku.Storerkey = PackDetail.Storerkey)  
                                AND (Sku.Sku = PackDetail.Sku)
      LEFT JOIN CODELKUP C WITH (nolock) ON C.storerkey= PackDetail.Storerkey AND C.listname = 'REPORTCFG' and C.code ='GetSkuMeasurement' AND C.long='r_dw_ucc_carton_label_51'
      WHERE (PackDetail.PickSlipNo= @c_PickSlipNo) AND (PackDetail.CartonNo = @c_CartonNo)
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      SELECT CartonNo,
             Style   ,
             BUSR6   ,
             CASE WHEN ISNULL(t2.SIZE,'') = '' THEN t1.Size ELSE t2.SIZE END AS Size,
             Qty     AS QTY
      FROM #Temp_51_1 t1
      LEFT JOIN #Temp_Size t2 ON t1.SIZE = t2.SIZE
      ORDER BY Style, BUSR6, t2.rowid
                      
   END

QUIT_SP:  
END -- procedure  

GO