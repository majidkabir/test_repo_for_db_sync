SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: nsp_UCC_CartonLabel_14                              */  
/* Creation Date: 16-May-2008                                           */  
/* Copyright: IDS                                                       */  
/* Written by: HF LIEW                                                  */  
/*                                                                      */  
/* Purpose: SOS#101322 - Generate Carton Manifest Label                 */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:																					                    */
/* Date        Author  Ver  Purposes                                    */  
/*                                                                      */  
/* 16-Mar-2009 Shong   1.1  SOS#131242 Gant's Carton Label              */
/* 24-Aug-2009 GTGOH	 1.2	SOS#145217	Add Barcode								      */
/* 19-Apr-2011 NJOW01  1.3  204305 - change mapping from consigneekey to*/
/*                          markforkey                                  */ 
/* 27-Dec-2011 NJOW02  1.4  233031 - Change barcode to orderkey         */
/************************************************************************/  
CREATE PROC [dbo].[nsp_UCC_CartonLabel_14] (
            @c_StorerKey NVARCHAR(5), 
            @c_PickSlipNo NVARCHAR(40), 
            @c_CartonNoStart NVARCHAR(3), 
            @c_CartonNoEnd NVARCHAR(3)  
)
AS  
BEGIN
   SET NOCOUNT ON

   DECLARE
   @c_startNumber          NVARCHAR(20),
   @c_selectedNumber       NVARCHAR(20),   
   @c_endNumber            NVARCHAR(20),
   @c_externorderkey_start NVARCHAR(20), 
   @c_externorderkey_end   NVARCHAR(20),
   @c_orderkey_start       NVARCHAR(10), 
   @c_orderkey_end         NVARCHAR(10),
   @nPosStart int, @nPosEnd int,
   @nDashPos                int ,
   @c_ExecStatements     nvarchar(4000),   
   @c_ExecStatements1    nvarchar(4000),
   @c_ExecStatements2    nvarchar(4000),
   @c_ExecStatements3    nvarchar(4000),
   @c_ExecStatements4    nvarchar(4000),
   @c_ExecStatementsMain nvarchar(4000),
   @c_ExecArguments      nvarchar(4000),
	@c_GantBar				 numeric,	-- SOS#145217
	@c_ChkDgt				 int,	-- SOS#145217
	@c_BarCode				 NVARCHAR(20)
   
   SELECT DISTINCT P.PickSlipNo,
   	    ORDERS.MarkForKey as LabelNo, 
   	    ORDERS.InvoiceNo, 
   	    ORDERS.ExternOrderKey, 
   	    PD.CartonNo, 
   	    ORDERS.MarkforKey,	--SOS#145217 Mask 
   	    ISNULL(ORDERS.M_Company,'') AS M_Company, 
   	    ISNULL(ORDERS.M_Address1,'') AS M_Address1, 
   	    ISNULL(ORDERS.M_Address2,'') AS M_Address2, 
   	    ISNULL(ORDERS.M_City,'') AS M_City, 
   	    ISNULL(ORDERS.M_COUNTRY,'') AS M_COUNTRY, 
   	    ISNULL(P.Route,'') AS Route, 
   	    ISNULL(ORDERS.M_Zip,'') AS M_Zip, 
-- SOS#145217 Mask
--   	    ' ' As ComputeCol,
--          0 As PriceLabel, 
--          ' ' As Notes2, 
--          ' ' As CartonType, 
          ORDERS.OrderKey
			 --(Substring(CODELKUP.Short,1,4) + ORDERS.OrderKey + '2') as GantBar	--SOS#145217 			 
	INTO #Temp	--SOS#145217
   FROM PACKHEADER P (NOLOCK) 
   JOIN PACKDETAIL PD (NOLOCK) ON P.PickSlipNo = PD.PickSlipNo 
   JOIN ORDERS WITH (NOLOCK) ON P.OrderKey = ORDERS.OrderKey 
	--JOIN CODELKUP (NOLOCK) ON Listname = 'GANTDHL'  --SOS#145217
	--AND  CODELKUP.Code = ORDERS.Markforkey 		--NJOW01
   WHERE P.PickSlipNo = @c_PickSlipNo 
   AND   PD.CartonNo Between  @c_CartonNoStart AND @c_CartonNoEnd
  
  
  /*
	SELECT @c_GantBar = GantBar from #Temp
	
	EXECUTE isp_CheckDigits @c_GantBar, 
				@c_ChkDgt Output
	
	Select @c_BarCode = (GantBar + Cast(@c_ChkDgt as  varchar)) from #Temp
	*/
	
	SELECT @c_BarCode = CONVERT(NVARCHAR(10),CONVERT(bigint, Orderkey)) from #Temp --NJOW02
	
	SELECT DISTINCT PickSlipNo, LabelNo, InvoiceNo, ExternOrderKey, 
   	    CartonNo, MarkForKey, M_Company, M_Address1, M_Address2, 
   	    M_City, M_COUNTRY, Route, M_Zip, ' ' As ComputeCol, 0 As PriceLabel, 
          ' ' As Notes2, ' ' As CartonType, OrderKey,
			 LTrim(RTrim(@c_BarCode)) as BarCode from #Temp
	
	Drop Table #Temp
	
	-- SOS#145217 End
END

GO