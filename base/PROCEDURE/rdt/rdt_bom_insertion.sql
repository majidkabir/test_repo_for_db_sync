SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_BOM_Insertion                                      */  
/* Copyright      : IDS                                                    */  
/*                                                                         */  
/* Purposes:                                                               */  
/* 1) To Match scanned ComponentSKU against BOM table                      */  
/*                                                                         */  
/* Called from: rdtfnc_BOMCreation                                         */  
/*                                                                         */  
/* Exceed version: 5.4                                                     */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date        Rev  Author      Purposes                                   */  
/* 07-Aug-2007 1.0  Vicky       Created                                    */  
/* 13-Oct-2007 1.1  Vicky       Insert Size = 88888 to determine           */  
/*                              it's ParentSKU  (Vicky01)                  */  
/* 03-Jun-2009 1.2  Vicky       Add Username when filter rdtBOMCreationLog */   
/*                              (Vicky02)                                  */ 
/* 2010-06-08  1.3  Shong       Accept Customer BOM Label                  */
/* 2010-06-16  1.4  James       SOS175733 - Add configkey 'STDBOMINDICATOR'*/
/*                              Insert SKUGROUP = 'BOM' (james01)          */
/*                              Use 1 as BOMQty                            */
/***************************************************************************/  
CREATE PROC [RDT].[rdt_BOM_Insertion] (
   @cStorerkey NVARCHAR(15)
  ,--@cParentSKU      NVARCHAR(20), -- first 15 chars  
   @cParentSKU NVARCHAR(18)	-- first 15 chars
  ,@cPackkey NVARCHAR(10)
  ,@nMobile INT
  ,@cUsername NVARCHAR(18)	-- (Vicky02)
  ,@cLangCode NVARCHAR(3)
  ,@nErrNo INT OUTPUT
  ,@cErrMsg NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
  ,@nFunc INT  -- (james01)
) AS  
BEGIN
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF  
    
    DECLARE @n_debug INT     
    
    SET @n_debug = 0  
    SET @nErrNo = 0 
    
    BEGIN TRAN 
    
    IF NOT EXISTS(SELECT 1 FROM dbo.SKU WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND SKU = RTRIM(@cParentSKU))
    BEGIN
       IF rdt.RDTGetConfig( @nFunc, 'STDBOMINDICATOR', @cStorerKey) = 1
       BEGIN
          -- Insert ParentSKU Into SKU Master (1 Record)  
          INSERT INTO dbo.SKU
            (
              Storerkey, SKU, DESCR, Packkey, Style, SKUGROUP
            )
          SELECT TOP 1 RTRIM(Storerkey)
                ,RTRIM(ParentSKU)
                ,RTRIM(Style)
                ,RTRIM(@cPackkey)
                ,RTRIM(Style)
                ,'BOM' -- (james01)
          FROM   RDT.rdtBOMCreationLog WITH (NOLOCK)
          WHERE  ParentSKU = RTRIM(@cParentSKU)
                 AND STATUS = '0'
                 AND MobileNo = @nMobile
                 AND Storerkey = @cStorerKey
                 AND Username = @cUsername  
       END
       ELSE
       BEGIN
          -- Insert ParentSKU Into SKU Master (1 Record)  
          INSERT INTO dbo.SKU
            (
              Storerkey, SKU, DESCR, Packkey, Style, [Size]
            )
          SELECT TOP 1 RTRIM(Storerkey)
                ,RTRIM(ParentSKU)
                ,RTRIM(Style)
                ,RTRIM(@cPackkey)
                ,RTRIM(Style)
                ,'88888' -- Vicky01
          FROM   RDT.rdtBOMCreationLog WITH (NOLOCK)
          WHERE  ParentSKU = RTRIM(@cParentSKU)
                 AND STATUS = '0'
    AND MobileNo = @nMobile
                 AND Storerkey = @cStorerKey
                 AND Username = @cUsername -- (Vicky02)         
       END
    END

    -- Insert into BOM (All ComponentSKU)  
    INSERT INTO dbo.BillOfMaterial
      (
        Storerkey, Sku, ComponentSku, [Sequence], Qty
      )
    SELECT RTRIM(RDTBOM.Storerkey)
          ,RTRIM(RDTBOM.ParentSKU)
          ,RTRIM(RDTBOM.ComponentSKU)
          ,RDTBOM.SequenceNo
          ,RDTBOM.Qty
    FROM   RDT.rdtBOMCreationLog RDTBOM WITH (NOLOCK) 
    LEFT OUTER JOIN dbo.BillOfMaterial BOM WITH (NOLOCK) ON 
         BOM.Storerkey = RDTBOM.StorerKey AND BOM.SKU = RDTBOM.ParentSKU AND BOM.ComponentSku = RDTBOM.ComponentSKU 
    WHERE  RDTBOM.ParentSKU = RTRIM(@cParentSKU)
           AND RDTBOM.STATUS = '0'
           AND RDTBOM.MobileNo = @nMobile
           AND RDTBOM.Storerkey = @cStorerKey
           AND RDTBOM.Username = @cUsername -- (Vicky02)  
           AND BOM.SKU IS NULL 


    IF @@ERROR=0
        COMMIT TRAN
    ELSE
    BEGIN
        ROLLBACK TRAN  
        SET @nErrNo = 63439  
        SET @cErrMsg = rdt.rdtgetmessage(63439 ,@cLangCode ,'DSP') -- Insrt SKU Fail  
        GOTO Fail
    END 
    
    Fail:
END

GO