SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_65_rdt                        */
/* Creation Date: 20-JUNE-2017                                          */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-2778- GBG bebe - Carton Content Label                   */
/*                                                                      */
/* Input Parameters: PickSlipNo, CartonNoStart, CartonNoEnd             */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_65_rdt                             */
/*                                                                      */
/* PVCS Version: 1.2                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 03-Mar-2018  CSCHONG  1.0  Fix Recgrp issue (CS01)                   */
/* 06-Jun-2018  LZG      1.1  INC0257025 - Added multiple PackKeys      */
/*                            compatibility & incorrect Qty shown (ZG01)*/
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_65_rdt] (
	     -- @c_storerkey      NVARCHAR(20)
         @c_PickSlipNo     NVARCHAR(20)
      ,  @c_StartCartonNo  NVARCHAR(20)
      ,  @c_EndCartonNo    NVARCHAR(20)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   
   DECLARE @c_GetPickSlipNo NVARCHAR(20),
           @c_ODPackkey     NVARCHAR(20),
           @c_SBusr1        NVARCHAR(30),
           @c_SSize         NVARCHAR(10),
           @c_scolor        NVARCHAR(30),
           @c_SKU           NVARCHAR(20),
           @n_BQty          INT,
           @c_getstorerkey  NVARCHAR(20),
           @c_storerkey     NVARCHAR(20),
           @n_NoOfLine      INT,
           @c_packkey       NVARCHAR(10)

  CREATE TABLE #TMP_UCCCTNLBL65_rdt (
         -- rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          labelno         NVARCHAR(20) NULL,
          OHUDF08         NVARCHAR(10) NULL,
          ODNotes         NVARCHAR(100) NULL,  
          Billtokey       NVARCHAR(15) NULL,
          OHUDF04         NVARCHAR(20) NULL,
          MarkForkey      NVARCHAR(15) NULL,
          ODPackkey       NVARCHAR(10) NULL,
          Storerkey       NVARCHAR(20) NULL,
          PQTY            INT,
          SColor          NVARCHAR(30) NULL,
          SBUSR1          NVARCHAR(30) NULL,
          SSIze           NVARCHAR(10) NULL,
          SKU             NVARCHAR(20) NULL,
          Recgroup        INT,
          ExtOrdKey       NVARCHAR(20) NULL         
			 )                    

		
		
	SET @c_storerkey   = ''
	SET @n_NoOfLine = 7
	SET @c_packkey = ''
	
	 --SELECT @c_storerkey = PH.StorerKey
	 --FROM PACKHEADER PH  (NOLOCK)	
	 --WHERE PH.Pickslipno = @c_PickSlipNo
	
	DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
	 SELECT DISTINCT ph.StorerKey,
	                 od.PackKey
    FROM PACKHEADER PH  (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo=PH.PickSlipNo
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey=PH.OrderKey 
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey AND Od.sku=Pd.SKU 
                                    AND OD.StorerKey=PD.StorerKey
   WHERE PD.Pickslipno = @c_PickSlipNo
   --AND   PD.Storerkey = @c_StorerKey
   AND   PD.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)                                
   
   OPEN CUR_RESULT                                                    
   FETCH NEXT FROM CUR_RESULT INTO @c_storerkey, @c_packkey            -- ZG01
   WHILE @@FETCH_STATUS <> -1                                           
   BEGIN    
	 
	IF @c_packkey = 'GBG_PACK' 
	BEGIN
   INSERT INTO #TMP_UCCCTNLBL65_rdt(labelno,OHUDF08,ODNotes,Pickslipno,Billtokey,OHUDF04,MarkForkey
                                  ,ODPackkey,Storerkey,SKU,SBUSR1,SColor,SSIze,Pqty,Recgroup,ExtOrdKey)  
   SELECT pd.LabelNo,oh.UserDefine09,OD.Notes,ph.PickSlipNo,oh.BillToKey,OH.UserDefine04,OH.MarkforKey,od.PackKey
         ,PH.StorerKey,od.sku,s.BUSR1,s.BUSR7,s.[Size],SUM(pd.qty) AS PQTY            
         ,(Row_Number() OVER (PARTITION BY PH.PickslipNo,pd.LabelNo ORDER BY pd.LabelNo,s.BUSR1,s.BUSR7,s.[Size] Asc) - 1)/@n_NoOfLine --CS01
         ,OH.ExternOrderKey
   FROM PACKHEADER PH  (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo=PH.PickSlipNo
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey=PH.OrderKey 
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey AND Od.sku=Pd.SKU 
                                    AND OD.StorerKey=PD.StorerKey
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey=OD.StorerKey AND s.sku = OD.Sku
	WHERE PD.Pickslipno = @c_PickSlipNo
   AND   PD.Storerkey = @c_StorerKey
   AND   OD.PackKey = @c_packkey                      -- ZG01
   AND   PD.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
   GROUP BY pd.LabelNo,oh.UserDefine09,od.Notes,ph.PickSlipNo,oh.BillToKey,OH.UserDefine04,OH.MarkforKey,od.PackKey,PH.StorerKey,od.sku
           ,s.BUSR1,s.BUSR7,s.[Size],od.notes,OH.ExternOrderKey
	END
	ELSE 
	BEGIN
	     INSERT INTO #TMP_UCCCTNLBL65_rdt(labelno,OHUDF08,ODNotes,Pickslipno,Billtokey,OHUDF04,MarkForkey
                                  ,ODPackkey,Storerkey,SKU,SBUSR1,SColor,SSIze,Pqty,Recgroup,ExtOrdKey)  
   SELECT pd.LabelNo,oh.UserDefine09,OD.Notes,ph.PickSlipNo,oh.BillToKey,OH.UserDefine04,OH.MarkforKey,od.PackKey
         ,PH.StorerKey,od.sku,s.BUSR1,s.BUSR7,s.[Size],SUM(pd.qty * BOM.Qty) AS PQTY                  -- ZG01
         ,(Row_Number() OVER (PARTITION BY PH.PickslipNo,pd.LabelNo ORDER BY pd.LabelNo,s.BUSR1,s.BUSR7,s.[Size] Asc) - 1)/@n_NoOfLine --CS01
         ,OH.ExternOrderKey
   FROM PACKHEADER PH  (NOLOCK)
   JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo=PH.PickSlipNo
   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey=PH.OrderKey 
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey AND Od.sku=Pd.SKU 
                                    AND OD.StorerKey=PD.StorerKey
   JOIN Billofmaterial BOM WITH (NOLOCK) ON BOM.Sku=OD.Sku AND  BOM.Storerkey=OD.StorerKey                                
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey=BOM.StorerKey AND s.sku = BOM.componentsku
	WHERE PD.Pickslipno = @c_PickSlipNo
   AND   PD.Storerkey = @c_StorerKey
   AND   OD.PackKey = @c_packkey                      -- ZG01    
   AND   PD.cartonno between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
   GROUP BY pd.LabelNo,oh.UserDefine09,od.Notes,ph.PickSlipNo,oh.BillToKey,OH.UserDefine04,OH.MarkforKey,od.PackKey,PH.StorerKey,od.sku
           ,s.BUSR1,s.BUSR7,s.[Size],od.notes,OH.ExternOrderKey 	
	END
 
   FETCH NEXT FROM CUR_RESULT INTO @c_storerkey, @c_packkey             
   END                       
   CLOSE CUR_RESULT                                            -- ZG01
   DEALLOCATE CUR_RESULT      

 /*  DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT pickslipno,sku ,Storerkey  
   FROM   #TMP_UCCCTNLBL65_rdt 
   WHERE pickslipno = @c_PickSlipNo
   AND Storerkey = @c_storerkey
   AND ODPackkey <> 'GBG_PACK' 
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_GetPickSlipNo,@c_SKU,@c_getstorerkey
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
   	
   	SET @c_SBusr1 = ''
   	SET @c_SSize = ''
   	SET @c_scolor = ''
   	SET @n_BQty = 0
   	
   	SELECT @c_SBusr1 = s.busr1
   	      ,@c_scolor = s.BUSR7
   	      ,@c_SSize  = s.[Size]
   	      ,@n_BQty = SUM(bom.qty)
   	FROM Billofmaterial BOM WITH (NOLOCK)
   	JOIN SKU S WITH (NOLOCK) ON s.sku = BOM.componentsku AND s.storerkey=BOM.storerkey
   	WHERE BOM.sku = @c_SKU
   	AND BOM.storerkey = @c_getstorerkey
   	GROUP BY s.busr1,s.BUSR7,s.[Size]
   	
   	UPDATE #TMP_UCCCTNLBL65_rdt
   	SET SBUSR1 = @c_SBusr1
   	   ,SColor = @c_scolor
   	   ,SSIze = @c_SSize
   	   ,PQTY = @n_BQty
   	WHERE SKU = @c_SKU
   	AND Storerkey=@c_getstorerkey
   	AND Pickslipno = @c_PickSlipNo	   
   	
   	
   FETCH NEXT FROM CUR_RESULT INTO @c_GetPickSlipNo,@c_SKU,@c_getstorerkey    
   END   */

	SELECT *
	FROM   #TMP_UCCCTNLBL65_rdt
	ORDER BY labelno,SBUSR1,SColor,SSIze
	
END


GO