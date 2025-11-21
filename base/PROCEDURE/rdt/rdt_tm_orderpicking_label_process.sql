SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_TM_OrderPicking_Label_Process                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Insert PackDetail after each scan of Case ID                */
/*                                                                      */
/* Called from: rdtfnc_TM_OrderPicking                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 20-May-2010 1.0  ChewKP    Created                                   */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_OrderPicking_Label_Process] (
   @nMobile              INT,
   @cFacility            NVARCHAR( 5),
   @cTaskStorer          NVARCHAR( 15),
   @cDropID              NVARCHAR( 18),
   @cOrderKey            NVARCHAR( 10),
   @cPickSlipNo          NVARCHAR( 10), -- can be conso ps# or discrete ps#; depends on pickslip type
   @cFilePath1           NVARCHAR( 20),
   @cFilePath2           NVARCHAR( 20),
   @cLangCode            VARCHAR (3),
	@cTaskdetailkey       NVARCHAR(10),
	@cPrepackByBOM			 NVARCHAR(1),
	@cUserName            NVARCHAR( 18),
   @cTemplateID          NVARCHAR( 20),
	@cPrinterID				 NVARCHAR( 20), 
   @nErrNo               INT          OUTPUT,
   @cErrMsg              NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max
   @cGS1TemplatePath_Final NVARCHAR( 120) OUTPUT,
	@nTotalCtnsALL			 INT			  OUTPUT,
	@c_LoosePick          NVARCHAR(1)      OUTPUT
) AS
BEGIN

   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_success         INT,
      @n_err             INT,
      @c_errmsg          NVARCHAR( 255)

   DECLARE

      
      @cGS1TemplatePath_Gen   NVARCHAR( 120), 
      @cGS1TemplatePath    NVARCHAR( 120),
   	@cGS1TemplatePath1   NVARCHAR( 20), 
   	@cGS1TemplatePath2   NVARCHAR( 20), 
      @cGS1TemplatePath3   NVARCHAR( 20), 
      @cGS1TemplatePath4   NVARCHAR( 20), 
      @cGS1TemplatePath5   NVARCHAR( 20), 
      @cGS1TemplatePath6   NVARCHAR( 20), 
      --@c_LoosePick         NVARCHAR( 1),
	   @cPackCheck			 NVARCHAR(  1),
	   @nTotalCtns          INT,
      @c_ALTSKU			 NVARCHAR( 20),
      @nUPCCaseCnt         INT,
      @nPDQTY              INT,
      @nTotalBOMQty        INT,
      @nLotCtns            INT,
		@cOutField01		 NVARCHAR( 60)

      SET @c_LoosePick     = '0'
		SET @cPackCheck      = '0'
		SET @nTotalCtns      = 0
		SET @c_ALTSKU        = '' 
		SET @nUPCCaseCnt     = 0 
		SET @nPDQTY          = 0 
		SET @nTotalBOMQty    = 0 
		SET @nLotCtns        = 0 
		SET @cOutField01     = '' 
		SET @nTotalCtnsALL   = 0
		

		IF ISNULL(RTRIM(@cTemplateID ), '') <> '' 
		BEGIN

	    SET @cGS1TemplatePath1 = ''
	    SET @cGS1TemplatePath2 = ''
	    SET @cGS1TemplatePath3 = ''
	    SET @cGS1TemplatePath4 = ''
	    SET @cGS1TemplatePath5 = ''
	    SET @cGS1TemplatePath6 = ''
		
		 SET @cGS1TemplatePath_Gen = ''

	    SELECT @cGS1TemplatePath_Gen = NSQLDescrip
	    FROM RDT.NSQLCONFIG WITH (NOLOCK)
	    WHERE ConfigKey = 'GS1TemplatePath'

	    SET @cGS1TemplatePath_Gen = ISNULL(RTRIM(@cGS1TemplatePath_Gen), '') + '\' + ISNULL(RTRIM(@cTemplateID), '')

	    SET @cGS1TemplatePath1 = LEFT(@cGS1TemplatePath_Gen, 20)
	    SET @cGS1TemplatePath2 = SUBSTRING(@cGS1TemplatePath_Gen, 21, 20)
	    SET @cGS1TemplatePath3 = SUBSTRING(@cGS1TemplatePath_Gen, 41, 20)
	    SET @cGS1TemplatePath4 = SUBSTRING(@cGS1TemplatePath_Gen, 61, 20)
	    SET @cGS1TemplatePath5 = SUBSTRING(@cGS1TemplatePath_Gen, 81, 20)
	    SET @cGS1TemplatePath6 = SUBSTRING(@cGS1TemplatePath_Gen, 101, 20)
    
	    SET @cGS1TemplatePath_Final = RTRIM(@cGS1TemplatePath1) + RTRIM(@cGS1TemplatePath2) + RTRIM(@cGS1TemplatePath3) +
											    RTRIM(@cGS1TemplatePath4) + RTRIM(@cGS1TemplatePath5) + RTRIM(@cGS1TemplatePath6)
      END       
	 
		
			-- PackHeader Creation and Ctn Counts (START) 
		

		IF @cPrepackByBOM = 1
		BEGIN
		  DECLARE CUR_PDLOT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
		  SELECT DISTINCT LA.Lottable03 FROM dbo.PickDetail PD WITH (NOLOCK) 
		  INNER JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (LA.Storerkey = PD.Storerkey AND LA.SKU = PD.SKU AND 
																			 LA.LOT = PD.LOT)
		  WHERE PD.StorerKey = @cTaskStorer  
		  --AND   PD.Orderkey = @cOrderkey -- (ChewKP01)
		  AND   PD.DropID = @cDropID
		  AND	  PD.TaskDetailkey = @cTaskDetailKey -- (ChewKP01)
		  OPEN CUR_PDLOT
		  FETCH NEXT FROM CUR_PDLOT INTO @c_ALTSKU
		  WHILE @@FETCH_STATUS <> -1
		  BEGIN

			  SET @nUPCCaseCnt = ''
			  SELECT @nUPCCaseCnt = ISNULL(PACK.CaseCnt, 0)
			  FROM dbo.PACK PACK WITH (NOLOCK)
			  JOIN dbo.UPC UPC WITH (NOLOCK) ON (UPC.Packkey = PACK.Packkey)
			  WHERE UPC.SKU = @c_ALTSKU
			  AND   UPC.Storerkey = @cTaskStorer
			  AND   UPC.UOM = 'CS'

  								  	
--  	           SELECT @nPDQTY = SUM(QTY) 
--	           FROM dbo.PickDetail WITH (NOLOCK)
--	           WHERE StorerKey = @cTaskStorer
--	           AND   Orderkey = @cOrderKey
--	           AND   DropID = @cDropID
			  SET @nPDQTY = 0
			  SELECT @nPDQTY = SUM(PD.QTY)
			  FROM dbo.PickDetail PD WITH (NOLOCK, INDEX(IDX_PICKDETAIL_DropID))
			  JOIN dbo.Lotattribute LA WITH (NOLOCK) ON (PD.Storerkey = LA.Storerkey and PD.SKU = LA.SKU AND
																				PD.LOT = LA.Lot) 
			  WHERE PD.DropID = @cDropID
			  AND   LA.Lottable03 = @c_ALTSKU
			  AND   PD.Storerkey = @cTaskStorer
			  AND	  PD.TaskDetailkey = @cTaskDetailKey -- (ChewKP01)
			  --AND   PD.Orderkey = @cOrderkey -- (ChewKP01)
		

			 IF @nUPCCaseCnt > 0
			 BEGIN
				  SET @nTotalBOMQty = 0
				  SELECT @nTotalBOMQty = SUM(BOM.QTY)
				  FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
				  WHERE BOM.Storerkey = @cTaskStorer
				  AND   BOM.SKU = @c_ALTSKU
				  		
				  SELECT @nLotCtns = CEILING(@nPDQTY / (@nTotalBOMQty * @nUPCCaseCnt))
				
				  IF (@nPDQTY % (@nTotalBOMQty * @nUPCCaseCnt)) > 0 
				  BEGIN
					  SET @c_LoosePick = '1'
					  --SET @cOutField03 = 'Loose pieces'
					  --SET @cOutField04 = 'found'
				  END
			  END
			  ELSE
			  BEGIN
				  SELECT @nLotCtns = 0
			  END

			  --SELECT @nUPCCaseCnt , @nPDQTY , @nTotalBOMQty
      
			  SELECT @nTotalCtns = @nTotalCtns + @nLotCtns

			  
      
			 FETCH NEXT FROM CUR_PDLOT INTO @c_ALTSKU
		  END
		  CLOSE CUR_PDLOT
		  DEALLOCATE CUR_PDLOT
		
		  SET @nTotalCtnsALL = @nTotalCtnsALL + @nTotalCtns

		  
	   END	-- IF @cPrepackByBOM = '1'	
	   ELSE 
	   BEGIN
	      
	      
	      SELECT @nPDQTY = PD.QTY , @nUPCCaseCnt = PACK.Casecnt FROM dbo.PickDetail PD (NOLOCK)
         INNER JOIN SKU SKU (NOLOCK) ON (SKU.SKU = PD.SKU AND SKU.STORERKEY = PD.STORERKEY ) 
         INNER JOIN PACK PACK (NOLOCK) ON (PACK.PACKKEY = SKU.PACKKEY)
         WHERE PD.TaskDetailKey = @cTaskdetailkey
         AND PD.Storerkey = @cTaskStorer
         AND PD.DROPID = @cDropID
	      --AND PD.Orderkey = @cOrderKey -- (ChewKP01)
	      
	      SELECT @nLotCtns = CEILING(@nPDQTY / @nUPCCaseCnt)
	      
	      SELECT @nTotalCtns = @nLotCtns
	      
	      SET @nTotalCtnsALL = @nTotalCtnsALL + @nTotalCtns
	      
	      
	      IF (@nPDQTY % @nUPCCaseCnt) > 0 
				  BEGIN
					  SET @c_LoosePick = '1'
					  --SET @cOutField03 = 'Loose pieces'
					  --SET @cOutField04 = 'found'
				  END
	      
	   END
			
		  	
		  
		  -- (ChewKP01) 
		  DECLARE CUR_PDMultiLot CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
		  SELECT PickSlipNo ,Orderkey  From dbo.PickDetail PD (NOLOCK)
		  WHERE PD.TaskDetailkey = @cTaskdetailkey
		  AND Storerkey = @cTaskStorer
		  
		  OPEN CUR_PDMultiLot
		  FETCH NEXT FROM CUR_PDMultiLot INTO @cPickSlipNo, @cOrderKey
		  WHILE @@FETCH_STATUS <> -1
		  BEGIN

   		  IF @nLotCtns > 0
   		  BEGIN
   				 IF NOT EXISTS (SELECT 1 FROM dbo.PACKHEADER WITH (NOLOCK)
   	            				 WHERE Pickslipno = @cPickslipNo)
   				 BEGIN -- Packheader not exists (Start)
   
   					 
   
   					 BEGIN TRAN
   					 INSERT INTO dbo.PackHeader 
   					 (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, TTLCNTS) -- (Vicky01)
   					 SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo,
   							  @nTotalCtns -- (Vicky01) 
   					 FROM  dbo.PickHeader PH WITH (NOLOCK)
   					 JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
   					 WHERE PH.PickHeaderKey = @cPickSlipNo
   
   					 IF @@ERROR <> 0
   					 BEGIN
   						 SET @nErrNo = 69619
   						 SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'
   					
   						 EXEC rdt.rdtSetFocusField @nMobile, 2
   						 ROLLBACK TRAN
   						 GOTO QUIT               
   					 END
   					 ELSE
   					 BEGIN
   						 COMMIT TRAN 
   					 END	
   				
   				 END -- IF NOT EXIST
   				 ELSE
   				 BEGIN
   
   						 BEGIN TRAN
   						 UPDATE dbo.PACKHEADER  WITH (ROWLOCK)
   						 SET TTLCNTS = (TTLCNTS + @nTotalCtns), Archivecop = NULL
   						 WHERE PickSlipNo = @cPickSlipNo
   						 AND Storerkey = @cTaskStorer
   
   						 IF @@ERROR <> 0
   						 BEGIN
   							 SET @nErrNo = 69616
   							 SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PHdrFail'
   						
   							 EXEC rdt.rdtSetFocusField @nMobile, 2
   							 ROLLBACK TRAN
   							 GOTO QUIT
   						 END
   						 ELSE
   						 BEGIN
   							 COMMIT TRAN 
   						 END	
   
   				END
   		  END -- @nLotCtns <> 0
   	 -- PackHeader Creation and Ctn Counts (END) 		
	
	     

            EXEC rdt.rdt_OPK_GS1_Carton_Label_InsertPackDetail 
         		      @nMobile,						
                     @cFacility,				
                     @cTaskStorer,				
                     @cDropID,				
                     @cOrderKey,				
                     @cPickSlipNo,				
                     @cFilePath1,				
                     @cFilePath2,				
                     @cGS1TemplatePath_Final, -- SOS# 140526 				
                     @cPrinterID,				
                     @cLangCode,				
                     @cTaskdetailkey,				
                     @cPrepackByBOM,				
                     @cUserName,					
                     @nErrNo        OUTPUT, 				
                     @cOutField01   OUTPUT
   
   	      IF @nErrNo <> 0
   	      BEGIN
   
   		      --SET @cOutField04 = CASE WHEN ISNULL(@nCasePackDefaultQty, 0) = 0 THEN '' ELSE @nCasePackDefaultQty END
   		      EXEC rdt.rdtSetFocusField @nMobile, 1
   		      GOTO QUIT
   	      END
   	  -- *** Carton Label Printing (End) *** --

       
	    /* -- Pack Confirmation (Start) (ChewKP02) --*/
       --DECLARE CUR_ORDER CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
--	    SELECT DISTINCT PD.Orderkey, PH.PickHeaderkey FROM PFCMODEL.dbo.PICKDETAIL PD WITH (NOLOCK)
--	    INNER JOIN PFCMODEL.dbo.PICKHEADER PH WITH (NOLOCK) ON ( PH.ORDERKEY = PD.ORDERKEY ) 
--	    INNER JOIN PFCMODEL.dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PD.ORDERKEY ) 
--	    WHERE PD.StorerKey = @cTaskStorer     
--	    AND   PH.ExternOrderKey = @cLoadkey
--		 AND   PD.DROPID = @cDropID
--	    ORDER BY PH.PickHeaderkey
   
	    --OPEN CUR_ORDER
	    --FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cPickSlipNo
	    --WHILE @@FETCH_STATUS <> -1
	    
   	               
		    -- (Vicky01) - Start
          DECLARE @nCntTotal INT, @nCntPrinted INT

          SET @nCntTotal = 0
          SET @nCntPrinted = 0

			 

          SELECT @nCntTotal = SUM(PD.QTY) FROM dbo.PICKDETAIL PD WITH (NOLOCK)
			 INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PD.ORDERKEY ) 
			 INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.ORDERKEY = OD.ORDERKEY AND 
                                                                       OD.OrderLineNumber = PD.OrderLinenUmber)
			 WHERE PD.StorerKey = @cTaskStorer 
			 AND O.ORDERKEY = @cOrderKey

          SELECT @nCntPrinted = SUM(PCD.QTY) FROM dbo.PACKDETAIL PCD WITH (NOLOCK)
			 INNER JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON ( PH.PickSlipNo = PCD.PickSlipNo ) 
			 INNER JOIN dbo.Orders O WITH (NOLOCK) ON ( O.ORDERKEY = PH.ORDERKEY ) 
			 WHERE O.StorerKey = @cTaskStorer 
			 AND O.ORDERKEY = @cOrderKey

          
          IF @nCntTotal = @nCntPrinted
          BEGIN
          -- (Vicky01) - End
			 			 			
						 BEGIN TRAN
						 UPDATE dbo.PACKHEADER WITH (ROWLOCK)
						 SET STATUS = '9'
						 WHERE PICKSLIPNO = @cPickslipNo
						 AND ORDERKEY = @cOrderKey

						 IF @@ERROR <> 0
						 BEGIN
							 SET @nErrNo = 69617
							 SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD PH FAILED'
							 EXEC rdt.rdtSetFocusField @nMobile, 2

							 ROLLBACK TRAN
							 GOTO QUIT
						 END
						 ELSE
						 BEGIN
							 COMMIT TRAN 
						 END	
			       
						 BEGIN TRAN      
						 UPDATE dbo.PICKINGINFO WITH (ROWLOCK)
						 SET SCANOUTDATE = GETDATE()
						 WHERE PickslipNo = @cPickslipNo 
			       
						 IF @@ERROR <> 0
						 BEGIN
							 SET @nErrNo = 69618
							 SET @cErrMSG = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SCAN OUT FAIL'
							 EXEC rdt.rdtSetFocusField @nMobile, 2

							 ROLLBACK TRAN
							 GOTO QUIT
						 END
						 ELSE
						 BEGIN
							 COMMIT TRAN 
						 END	
--
--					 FETCH NEXT FROM CUR_PACKCONFIRM INTO @cOrderKey , @cPickSlipNo
--				END -- END WHILE
			 --END --END IF
			 -- Process Confirm Pack (END) --
			/***************************************************************/
		    -- Process Confirm Pack (END) --
			--FETCH NEXT FROM CUR_ORDER INTO @cOrderKey , @cPickSlipNo
      
		   END
		--CLOSE CUR_ORDER
		--DEALLOCATE CUR_ORDER
		/* -- Pack Confirmation (END) (ChewKP02) --*/
		
		FETCH NEXT FROM CUR_PDMultiLot INTO @cPickSlipNo, @cOrderKey
		
	  END --  While CUR_PDMultiLot
	  CLOSE CUR_PDMultiLot
	  DEALLOCATE CUR_PDMultiLot
QUIT:		
END

GO