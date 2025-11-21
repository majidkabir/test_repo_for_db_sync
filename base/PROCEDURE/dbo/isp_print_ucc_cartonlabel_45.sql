SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_Print_UCC_CartonLabel_45                        */
/* Creation Date: 01-August-2016                                        */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  CN-LBI MAST VSBA Carton Label  (SOS371502)                 */
/*                                                                      */
/* Input Parameters: @cStorerKey - StorerKey,                           */
/*                   @cPickSlipNo - Pickslipno,                         */
/*                   @cFromCartonNo - From CartonNo,                    */
/*                   @cToCartonNo - To CartonNo,                        */
/*                                                                      */
/*                                                                      */
/* Usage: Call by dw = r_dw_ucc_carton_label_44                         */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_Print_UCC_CartonLabel_45] ( 
   @c_StorerKey    NVARCHAR( 15),
   @c_PickSlipNo   NVARCHAR( 10), 
   @c_FromCartonNo NVARCHAR( 10),
   @c_ToCartonNo   NVARCHAR( 10) )
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_debug int

   DECLARE 
      @nFromCartonNo         int,
      @nToCartonNo           int,
      @cUCC_LabelNo          NVARCHAR( 20),
      @n_CntExtOrdKey        INT
      
     


   DECLARE @n_Address1Mapping INT
         , @n_C_CityMapping   INT
   
   SET @b_debug = 0
   SET @n_CntExtOrdKey = 1

   SET @nFromCartonNo = CAST( @c_FromCartonNo AS int)
   SET @nToCartonNo = CAST( @c_ToCartonNo AS int)
   
   
   
   CREATE TABLE #TempCartonLabel_45
	(
		Consigneekey       NVARCHAR(20) NULL,
      C_Company          NVARCHAR(45) NULL,
      C_Address1         NVARCHAR(45) NULL,            
		C_Address2         NVARCHAR(45) NULL,
		C_Address3         NVARCHAR(45) NULL,
		C_Address4         NVARCHAR(45) NULL,
		C_State            NVARCHAR(45) NULL,
		C_City             NVARCHAR(45) NULL,
		ExternOrderkey     NVARCHAR(50) NULL,  --tlting_ext
      MarkForKey         NVARCHAR(15) NULL,
      loadkey          NVARCHAR(20) NULL
    
	)     
	
	
	  --SELECT @n_CntExtOrdKey = COUNT(DISTINCT ORD.externorderkey)
	  --FROM dbo.ORDERS ORD WITH (NOLOCK)
   --  JOIN  Packheader PH WITH (NOLOCK) 
   --  ON ORD.LoadKey = PH.loadkey
   --  JOIN PackDetail PD WITH (NOLOCK)
   --  ON PD.PickSlipNo=PH.PickSlipNo
   --  WHERE PH.Pickslipno = @c_PickSlipNo
   --  AND PH.Storerkey = @c_StorerKey
   --  AND CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo
	
	
	   INSERT INTO #TempCartonLabel_45(Consigneekey,C_Company,C_Address1,C_Address2,C_Address3,
	                                    C_Address4,C_State,C_City,ExternOrderkey,MarkForKey,loadkey)
	   SELECT TOP 1 ORD.Consigneekey AS Consigneekey
               ,C_Company AS C_Company
               ,C_Address1 AS C_Address1
               ,C_Address2 AS C_Address2
               ,C_Address3 AS C_Address3
               ,C_Address4 AS C_Address4
               ,C_State AS C_State
               ,C_City AS C_City
               ,''--,CASE WHEN @n_CntExtOrdKey = 1 THEN ExternOrderkey ELSE '' END AS ExternOrderkey
               ,MarkForKey AS MarkForKey
               ,ORD.LoadKey AS loadkey
                FROM dbo.ORDERS ORD WITH (NOLOCK)
                JOIN  Packheader PH WITH (NOLOCK) 
                ON ORD.LoadKey = PH.loadkey
                JOIN PackDetail PD WITH (NOLOCK)
                ON PD.PickSlipNo=PH.PickSlipNo
               WHERE PH.Pickslipno = @c_PickSlipNo
               AND PH.Storerkey = @c_StorerKey
               AND CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo
               
               
              -- SELECT * FROM #TempCartonLabel_45
	
	  	SELECT ''
		  ,  T45.Consigneekey AS Consigneekey
		  ,  T45.C_Company  AS C_Company
		  , T45.C_Address1  AS C_Address1
		  , T45.C_Address2  AS C_Address2
		  , T45.C_Address3  AS C_Address3
		  , T45.C_Address4  AS C_Address4
		  , T45.C_State  AS C_State
		  , T45.C_City  AS C_City
		  , T45.ExternOrderkey AS ChildExternOrderkey
	  	  , dbo.ORDERS.BillToKey
	  	  , T45.MarkForKey
        , dbo.PackDetail.PickSlipNo
        , dbo.PackDetail.CartonNo
        , dbo.PackDetail.LabelNo
        /*, Qty = SUM(dbo.PackDetail.Qty)*/
        , Qty = (SELECT SUM(PD.QTY) FROM dbo.PACKDETAIL PD (NOLOCK) WHERE PD.Pickslipno = dbo.PackDetail.Pickslipno
                 AND PD.cartonno = dbo.PackDetail.Cartonno)
		  , ISNULL(PackHeader.Storerkey,'') AS Storerkey
	  	  , dbo.STORER.Company
	  	  , dbo.STORER.Address1
	  	  , dbo.STORER.Address2
	  	  , dbo.STORER.Address3
	  	  , dbo.STORER.Address4
	  	  , dbo.STORER.State
	  	  , dbo.STORER.City
	  	  , ('2' + Right(PackHeader.LoadKey,9)) AS ShipmentNo
     FROM dbo.PackHeader WITH (NOLOCK) 
     JOIN dbo.ORDERS WITH (NOLOCK)   
	    ON (dbo.PackHeader.loadkey = dbo.ORDERS.loadkey) 
     JOIN dbo.PackDetail WITH (NOLOCK) 
	    ON (dbo.PackHeader.PickSlipNo = dbo.PackDetail.PickSlipNo) 
     JOIN dbo.STORER SR WITH (NOLOCK)
       ON (dbo.ORDERS.Storerkey = SR.Storerkey)
     LEFT JOIN dbo.STORER WITH (NOLOCK) 
	    ON (dbo.STORER.Storerkey =  RTRIM(dbo.ORDERS.BillToKey)+RTRIM(dbo.ORDERS.ConsigneeKey))
     LEFT JOIN dbo.CODELKUP WITH (NOLOCK)
       ON (dbo.ORDERS.BillToKey = dbo.CODELKUP.Code AND dbo.CODELKUP.Listname = 'LFA2LFK')     
     LEFT JOIN #TempCartonLabel_45 T45 ON T45.loadkey = PackHeader.LoadKey
    WHERE (dbo.PackHeader.PickSlipNo= @c_PickSlipNo)
	   AND (dbo.PackHeader.Storerkey = @c_StorerKey)
	   AND (dbo.PackDetail.CartonNo BETWEEN @nFromCartonNo AND @nToCartonNo )
 GROUP BY 
		     T45.Consigneekey 
		  ,  T45.C_Company  
		  , T45.C_Address1  
		  , T45.C_Address2  
		  , T45.C_Address3  
		  , T45.C_Address4  
		  , T45.C_State  
		  , T45.C_City  
		  , T45.ExternOrderkey 
		  , dbo.ORDERS.BillToKey
		  ,T45.MarkForKey
		  , dbo.PackDetail.PickSlipNo
		  , dbo.PackDetail.CartonNo
		  , dbo.PackDetail.LabelNo
		  , ISNULL(PackHeader.Storerkey,'')
		  , dbo.STORER.Company
		  , dbo.STORER.Address1
		  , dbo.STORER.Address2
		  , dbo.STORER.Address3
		  , dbo.STORER.Address4
		  , dbo.STORER.State
		  , dbo.STORER.City
		  ,'2' + Right(PackHeader.LoadKey,9)
 ORDER BY dbo.PackDetail.CartonNo
 
DROP TABLE #TempCartonLabel_45

END

GO