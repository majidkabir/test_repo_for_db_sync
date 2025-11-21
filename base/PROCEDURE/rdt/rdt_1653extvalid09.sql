SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***********************************************************************************/          
/* Store procedure: rdt_1653ExtValid09                                             */          
/* Copyright      : MAERSK                                                         */          
/*                                                                                 */          
/* Date        Rev  Author   Purposes                                              */          
/* 2023-05-22  1.0  James    WMS-22499 Created                                     */    
/* 2023-11-16  1.1  SY       Temp Fix (SY1)                                        */    
/* 2023-11-14  1.2  James    WMS-23712 Extend Lane var length (james01)            */  
/* 2024-01-16  1.3  James    WMS-23948 Add check max allowed buyerpo               */
/*                           per lane (james02)                                    */
/* 2024-05-07  1.4  WyeChun  JSM-224226 Enhance Float calculation (WC01)           */  
/* 2024-05-08  1.5  WyeChun  JSM-224386 Use BillToKey for @cOrdChkConsignee (WC02) */  
/***********************************************************************************/          
          
CREATE   PROC [RDT].[rdt_1653ExtValid09] (          
   @nMobile        INT,      
   @nFunc          INT,      
   @cLangCode      NVARCHAR( 3),      
   @nStep          INT,      
   @nInputKey      INT,      
   @cFacility      NVARCHAR( 5),      
   @cStorerKey     NVARCHAR( 15),      
   @cTrackNo       NVARCHAR( 40),      
   @cOrderKey      NVARCHAR( 20),      
   @cPalletKey     NVARCHAR( 20),      
   @cMBOLKey       NVARCHAR( 10),      
   @cLane          NVARCHAR( 30),      
   @tExtValidVar   VariableTable READONLY,      
   @nErrNo         INT           OUTPUT,      
   @cErrMsg        NVARCHAR( 20) OUTPUT      
) AS          
BEGIN          
      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE       
       @nNoMixPallet          INT = 0,       
       @nPalletExists         INT = 0,      
       @cPalletCriteria       NVARCHAR( 30),      
       @cOrdChkField          NVARCHAR( 100),      
       @cOrdChkConsignee      NVARCHAR( 100),       
       @cOrdChkShipper        NVARCHAR( 100),       
       @cOrdPalletizedField   NVARCHAR( 30) = '',       
       @cPltPalletizedField   NVARCHAR( 30) = '',      
       @c_OriExecStatements   NVARCHAR( MAX),      
       @c_ExecStatements      NVARCHAR( MAX),       
       @c_ExecArguments       NVARCHAR( MAX),      
       @cOpenPalletizedPlt    NVARCHAR(20),          
       @cCheckOpenPalletizedPallet NVARCHAR(1),      
       @cPltCustOverrideClause   NVARCHAR(MAX)       
             
   DECLARE @fMinHeight        FLOAT = 0      
   DECLARE @fMaxHeight        FLOAT = 0   
   DECLARE @fORIMinHeight     FLOAT = 0   --WC01  
   DECLARE @fORIMaxHeight     FLOAT = 0   --WC01      
   DECLARE @fHeight           FLOAT = 0      
   DECLARE @cHeight           NVARCHAR( 10)      
   DECLARE @cUDF03            NVARCHAR( 60)      
   DECLARE @cLaneShipperKey   NVARCHAR( 15)      
   DECLARE @cOrdShipperKey    NVARCHAR( 15)      
   DECLARE @cLaneWaveKey      NVARCHAR( 10)      
   DECLARE @cOrdWaveKey       NVARCHAR( 10)      
   DECLARE @nLaneCtnCnt       INT = 0      
   DECLARE @nUnscannedCtnCnt  INT = 0      
   DECLARE @nOrdCtnCnt        INT = 0      
   DECLARE @nMaxLaneCtnCnt    INT = 0      
   DECLARE @nMaxPltCtnCnt     INT = 0      
   DECLARE @nLaneNoMixWave    INT = 0      
   DECLARE @nLaneNoMixShipper INT = 0      
   DECLARE @nLaneNoMixPltCustomer   INT = 0      
   DECLARE @nOrdHasPltCustomer      INT = 0      
   DECLARE @nLaneHasPltCustomer     INT = 0      
   DECLARE @cErrMsg1          NVARCHAR( 20),      
           @cErrMsg2          NVARCHAR( 20),      
           @cErrMsg3          NVARCHAR( 20),      
           @cErrMsg4          NVARCHAR( 20),      
           @cErrMsg5          NVARCHAR( 20)      
   DECLARE @cOrderType        NVARCHAR( 10)    
   DECLARE @nFilterOrdType    INT = 0    
   DECLARE @cBillToKey        NVARCHAR( 15)  
   DECLARE @nLaneBuyerPO         INT = 0  
   DECLARE @nAllowedLaneBuyerPO  INT = 0  
DECLARE @cAllowedLaneBuyerPO  NVARCHAR( 60) = ''  
   DECLARE @cBuyerPO          NVARCHAR( 20) = ''                           
       
   IF @nStep IN ( 2, 3, 5) -- PalletKey      
   BEGIN      
      IF @nInputKey = 1 -- ENTER      
      BEGIN      
         -- Check if the order needs to be palletized as no mix      
         SELECT       
               @cOrdPalletizedField = ISNULL(CL.Long, ''),      
               @cPltCustOverrideClause = ISNULL(CL.Notes, ''),      
               @cBillToKey = ISNULL( O.BillToKey, ''),  
               @cBuyerPO = ISNULL( O.BuyerPO, '')                              
         FROM dbo.ORDERS O WITH (NOLOCK)       
         JOIN dbo.CODELKUP CL WITH (NOLOCK) ON       
            ( O.BillToKey = CL.Code AND O.StorerKey = CL.StorerKey)      
         WHERE OrderKey = @cOrderKey      
         AND   CL.ListName = 'NOMIXPLSHP'      
         AND   CL.Storerkey = @cStorerKey      
               
         -- Get order's palletize criteria       
         IF @cOrdPalletizedField <> ''      
         BEGIN       
               SET @c_ExecStatements = N' SELECT @cOrdChkField = ' + @cOrdPalletizedField       
                                    --+ ',       @cOrdChkConsignee = ConsigneeKey '  --WC02    
                                    + ',       @cOrdChkConsignee = BillToKey '       --WC02   
                                    + ',       @cOrdChkShipper = ShipperKey '      
                                    + ' FROM dbo.ORDERS WITH (NOLOCK) '      
                                    + ' WHERE OrderKey = @cOrderKey '      
               SET @c_ExecArguments = N'@cOrderKey NVARCHAR(10)'      
                                 + ', @cOrdPalletizedField NVARCHAR(20)'      
                                 + ', @cOrdChkField NVARCHAR(100) OUTPUT'      
                                 + ', @cOrdChkConsignee NVARCHAR(100) OUTPUT'      
                                 + ', @cOrdChkShipper NVARCHAR(100) OUTPUT'      
               EXEC sp_ExecuteSql   @c_ExecStatements      
                                 , @c_ExecArguments      
                                 , @cOrderKey      
                                 , @cOrdPalletizedField      
                                 , @cOrdChkField OUTPUT      
                                 , @cOrdChkConsignee OUTPUT       
                                 , @cOrdChkShipper OUTPUT       
         END       
      
         -- If PalletKey exists, then further check the palletization constraints      
         --      - If pallet is specially palletized, then check if scanned order can be merged into the pallet      
         --      - If pallet is not specially palletized, then check if scanned order has palletize criteria       
         -- Else allow to palletize in a new pallet       
      
         -- Check if the scanned pallet is specially palletized       
         SELECT       
            @cPltPalletizedField = ISNULL(CL.Long, ''),      
            @nPalletExists = 1      
         FROM dbo.PalletDetail PD WITH (NOLOCK)      
         JOIN dbo.ORDERS WITH (NOLOCK) ON PD.UserDefine01 = Orders.OrderKey AND PD.StorerKey = Orders.StorerKey       
         LEFT JOIN dbo.CODELKUP CL WITH (NOLOCK) ON       
            ( Orders.BillToKey = CL.Code AND Orders.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP')      
         WHERE PD.PalletKey = @cPalletKey      
      
         IF @nPalletExists = 1      
         BEGIN       
            SET @c_ExecStatements = ''      
            SET @c_ExecArguments = ''      
            SELECT @c_OriExecStatements = N' SELECT @nNoMixPallet = 1 ' + CASE WHEN @cPltPalletizedField <> '' THEN + ', @cPalletCriteria =  ISNULL(' + @cPltPalletizedField + ', '''') ' ELSE ', @cPalletCriteria = ''''' END
                                    + ' FROM PalletDetail PD (NOLOCK) '    
                                    + ' JOIN dbo.ORDERS WITH (NOLOCK) ON ( PD.UserDefine01 = Orders.OrderKey AND PD.StorerKey = Orders.StorerKey) '      
                                    + ' WHERE Orders.StorerKey = @cStorerKey '      
                                    + ' AND   PD.PalletKey = @cPalletKey '        
      
            SET @c_ExecArguments = N'@cStorerKey        NVARCHAR(15)'      
                              + ', @cPalletKey          NVARCHAR(20)'      
                              + ', @nNoMixPallet        INT OUTPUT'      
                              + ', @cOrdChkField        NVARCHAR(100)'      
                              + ', @cOrdChkConsignee    NVARCHAR(100)'      
                              + ', @cOrdChkShipper      NVARCHAR(100)'      
                              + ', @cOrdPalletizedField NVARCHAR(30)'      
                              + ', @cPltPalletizedField NVARCHAR(30)'      
                              + ', @cOrderKey           NVARCHAR(10)'      
                              + ', @cPltCustOverrideClause  NVARCHAR(MAX)'      
                              + ', @cPalletCriteria     NVARCHAR(30) OUTPUT'     
      
            -- If pallet is specially palletized, then check if scanned order can be merge into the pallet with the criteria       
            IF @cPltPalletizedField <> ''       
            BEGIN       
               --SET @c_ExecStatements = @c_OriExecStatements + ' AND (' + @cPltPalletizedField + ' <> @cOrdChkField OR Orders.ConsigneeKey <> @cOrdChkConsignee OR Orders.ShipperKey <> @cOrdChkShipper) ' --WC02    
               SET @c_ExecStatements = @c_OriExecStatements + ' AND (' + @cPltPalletizedField + ' <> @cOrdChkField OR Orders.BillToKey <> @cOrdChkConsignee OR Orders.ShipperKey <> @cOrdChkShipper) '      --WC02    
               EXEC sp_ExecuteSql   @c_ExecStatements      
                                 , @c_ExecArguments      
                                 , @cStorerKey      
                                 , @cPalletKey      
                                 , @nNoMixPallet OUTPUT       
                                 , @cOrdChkField      
                                 , @cOrdChkConsignee      
                                 , @cOrdChkShipper      
                                 , @cOrdPalletizedField      
                                 , @cPltPalletizedField      
                                 , @cOrderKey      
                                 , @cPltCustOverrideClause      
                                 , @cPalletCriteria OUTPUT       
              
               IF @nNoMixPallet = 1      
               BEGIN      
                  SET @nErrNo = 0        
                  SET @cErrMsg1 = rdt.rdtgetmessage( 201251, @cLangCode, 'DSP') -- ERROR:      
                  SET @cErrMsg2 = rdt.rdtgetmessage( 201252, @cLangCode, 'DSP') -- PALLET IS SPECIALLY      
                  SET @cErrMsg3 = rdt.rdtgetmessage( 201253, @cLangCode, 'DSP') -- PALLETIZED BY      
                  SET @cErrMsg4 = @cPalletCriteria        
                  SET @cErrMsg5 = ''        
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                        @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5        
                  IF @nErrNo = 1        
                  BEGIN        
                     SET @cErrMsg1 = ''        
                     SET @cErrMsg2 = ''        
                     SET @cErrMsg3 = ''        
                     SET @cErrMsg4 = ''      
                     SET @cErrMsg5 = ''      
                  END        
                           
                  SET @nErrNo = 201251      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
                  GOTO Quit      
               END      
            END      
      
            -- If order has palletize criteria, then check if scanned order can be merge into the pallet with the criteria       
            IF @cOrdPalletizedField <> ''       
            BEGIN         
               --SET @c_ExecStatements = @c_OriExecStatements + ' AND (' + @cOrdPalletizedField + ' <> @cOrdChkField OR Orders.ConsigneeKey <> @cOrdChkConsignee OR Orders.ShipperKey <> @cOrdChkShipper) ' --WC02    
               SET @c_ExecStatements = @c_OriExecStatements + ' AND (' + @cOrdPalletizedField + ' <> @cOrdChkField OR Orders.BillToKey <> @cOrdChkConsignee OR Orders.ShipperKey <> @cOrdChkShipper) '      --WC02    
                                     + CASE WHEN @cPltCustOverrideClause <> '' THEN ' AND NOT EXISTS (' + @cPltCustOverrideClause + ') ' ELSE '' END      
               EXEC sp_ExecuteSql   @c_ExecStatements      
                                 , @c_ExecArguments      
                                 , @cStorerKey      
                                 , @cPalletKey      
                                 , @nNoMixPallet OUTPUT       
                                 , @cOrdChkField      
                                 , @cOrdChkConsignee      
                                 , @cOrdChkShipper      
                                 , @cOrdPalletizedField      
                                 , @cPltPalletizedField      
                                 , @cOrderKey      
                                 , @cPltCustOverrideClause      
                                 , @cPalletCriteria OUTPUT       
      
               IF @nNoMixPallet = 1      
               BEGIN      
                  SET @nErrNo = 0        
                  SET @cErrMsg1 = rdt.rdtgetmessage( 201254, @cLangCode, 'DSP') -- ERROR:      
                  SET @cErrMsg2 = rdt.rdtgetmessage( 201255, @cLangCode, 'DSP') -- ORDER NEED TO BE      
                  SET @cErrMsg3 = rdt.rdtgetmessage( 201256, @cLangCode, 'DSP') -- PALLETIZED BY      
                  SET @cErrMsg4 = @cOrdChkField        
                  SET @cErrMsg5 = rdt.rdtgetmessage( 201257, @cLangCode, 'DSP') -- CANNOT MIX PALLET        
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                        @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5        
                  IF @nErrNo = 1        
                  BEGIN        
                     SET @cErrMsg1 = ''        
                     SET @cErrMsg2 = ''        
                     SET @cErrMsg3 = ''        
                     SET @cErrMsg4 = ''      
                     SET @cErrMsg5 = ''      
                  END        
                           
                  SET @nErrNo = 201254      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
                  GOTO Quit      
               END      
            END      
         END      
    
         -- (james01)    
         SELECT @cOrderType = [Type]    
         FROM dbo.ORDERS WITH (NOLOCK)    
         WHERE OrderKey = @cOrderKey    
             
         IF EXISTS ( SELECT 1    
                     FROM dbo.CODELKUP WITH (NOLOCK)      
                     WHERE ListName = 'LANECONFIG'      
                     AND   Code = 'LANE'    
                     AND   Storerkey = @cStorerKey      
                     AND   code2 = @cOrderType)    
            SET @nFilterOrdType = 1    
         ELSE     
          SET @nFilterOrdType = 0    
              
         SELECT @nMaxLaneCtnCnt = ISNULL(Short, 0)       
         FROM dbo.CODELKUP WITH (NOLOCK)      
         WHERE ListName = 'LANECONFIG'      
         AND   Code = 'LANE'      
         AND   Storerkey = @cStorerKey      
         AND   (( @nFilterOrdType = 0 AND code2 = '') OR ( @nFilterOrdType = 1 AND code2 = @cOrderType))    
             
         -- Override global lane limit         
         SELECT @nMaxLaneCtnCnt = ISNULL(NoOfCustomerCarton, @nMaxLaneCtnCnt)         
         FROM dbo.MBOL M WITH (NOLOCK)        
         JOIN dbo.PalletDetail PD WITH (NOLOCK) ON PD.UserDefine03 = M.ExternMBOLKey      
         WHERE StorerKey = @cStorerKey      
         AND ExternMBOLKey = @cLane        
               
         IF @nMaxLaneCtnCnt > 0      
         BEGIN      
             -- Get total cartons in the lane (Exclude the to-be scanned order)          
             SELECT @nLaneCtnCnt = COUNT(1)       
             FROM dbo.PalletDetail PD WITH (NOLOCK)      
             JOIN dbo.MBOL M WITH (NOLOCK) ON ( PD.UserDefine03 = M.ExternMBOLKey)      
             WHERE PD.StorerKey = @cStorerKey      
             AND   PD.UserDefine03 = @cLane      
             AND   M.Status < '9'      
             AND   PD.UserDefine01 <> @cOrderKey      
                   
             -- Get to-be scanned order's total cartons      
             SELECT @nOrdCtnCnt = COUNT(DISTINCT LabelNo)      
             FROM dbo.PackDetail PD WITH (NOLOCK)      
             JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)      
             WHERE OrderKey = @cOrderKey      
      
             /*      
             -- Get unscanned cartons in the lane, for orders which are scanned to pallet partially      
             SELECT @nUnscannedCtnCnt = COUNT(DISTINCT LabelNo)       
             FROM dbo.PackDetail PD WITH (NOLOCK)      
             JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)      
             JOIN dbo.Orders O WITH (NOLOCK) ON ( O.OrderKey = PH.OrderKey)      
             LEFT JOIN dbo.PalletDetail PLD WITH (NOLOCK) ON       
               ( PLD.CaseID = PD.LabelNo AND PD.StorerKey = PLD.StorerKey AND PLD.UserDefine01 = PH.OrderKey)      
             WHERE PH.StorerKey = @cStorerKey      
             AND   O.Status < '9'      
             AND   PLD.UserDefine03 = @cLane       
             AND   PLD.CaseID IS NULL       
             */      
                   
             -- Get unscanned cartons in the lane, for orders which are scanned to pallet partially (Exclude the to-be scanned order)           
             SELECT @nUnscannedCtnCnt = COUNT(DISTINCT PLD.LabelNo)        
             FROM dbo.MBOL M WITH (NOLOCK)        
             JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON ( MD.MBOLKey = M.MBOLKey)          
             OUTER APPLY (          
                 SELECT DISTINCT PD.LabelNo, PLD.CaseID, PD.StorerKey FROM PackDetail PD (NOLOCK)          
                 JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo           
                 LEFT JOIN dbo.PalletDetail PLD WITH (NOLOCK) ON           
                 ( PLD.CaseID = PD.LabelNo AND PLD.StorerKey = PD.StorerKey AND           
                 PLD.UserDefine01 = PH.OrderKey AND PLD.UserDefine03 = M.ExternMBOLKey)          
                 WHERE PH.StorerKey = @cStorerKey        
                 AND PH.OrderKey = MD.OrderKey          
             ) PLD         
             WHERE PLD.StorerKey = @cStorerKey         
             AND   M.Status < '9'          
             AND   M.ExternMBOLKey = @cLane           
             AND   MD.OrderKey <> @cOrderKey        
             AND   PLD.CaseID IS NULL            
                   
             IF @nLaneCtnCnt > 0 AND (@nLaneCtnCnt + @nUnscannedCtnCnt + @nOrdCtnCnt > @nMaxLaneCtnCnt)       
             BEGIN      
               IF NOT EXISTS (      
                  SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)      
                  WHERE StorerKey = @cStorerKey      
                  AND UserDefine03 = @cLane      
                  AND UserDefine01 = @cOrderKey)      
               BEGIN      
                  SET @nErrNo = 0        
                  SET @cErrMsg1 = rdt.rdtgetmessage( 201262, @cLangCode, 'DSP') -- EXCEED MAX CARTON      
                  SET @cErrMsg2 = rdt.rdtgetmessage( 201263, @cLangCode, 'DSP') -- PER LANE      
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                        @cErrMsg1, @cErrMsg2        
                  IF @nErrNo = 1        
                  BEGIN        
                     SET @cErrMsg1 = ''        
                     SET @cErrMsg2 = ''        
                  END        
                              
                  SET @nErrNo = 201262      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
                  GOTO Quit      
               END      
             END      
   END      
    
         IF EXISTS ( SELECT 1       
                     FROM dbo.Codelkup WITH (NOLOCK)      
                     WHERE ListName = 'LANECONFIG'      
                     AND   Code = 'PALLET'      
                     AND   Storerkey = @cStorerKey    
                     AND   code2 = @cOrderType)    
            SET @nFilterOrdType = 1    
         ELSE    
          SET @nFilterOrdType = 0    
    
         SET @nMaxPltCtnCnt = ''    
         SELECT @nMaxPltCtnCnt = ISNULL(Short, 0)       
         FROM dbo.Codelkup WITH (NOLOCK)      
         WHERE ListName = 'LANECONFIG'      
         AND   Code = 'PALLET'      
         AND   Storerkey = @cStorerKey      
         AND   (( @nFilterOrdType = 0 AND code2 = '') OR ( @nFilterOrdType = 1 AND code2 = @cOrderType))    
             
         IF @nMaxPltCtnCnt > 0 AND       
         EXISTS ( SELECT 1       
                  FROM dbo.PalletDetail PLD WITH (NOLOCK)      
                  WHERE PalletKey = @cPalletKey       
                  GROUP BY PalletKey       
                  HAVING COUNT(1) > @nMaxPltCtnCnt)      
         BEGIN      
            SET @nErrNo = 0        
            SET @cErrMsg1 = rdt.rdtgetmessage( 201264, @cLangCode, 'DSP') -- EXCEED MAX CARTON      
            SET @cErrMsg2 = rdt.rdtgetmessage( 201265, @cLangCode, 'DSP') -- PER PALLET      
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                  @cErrMsg1, @cErrMsg2        
            IF @nErrNo = 1        
            BEGIN        
               SET @cErrMsg1 = ''        
               SET @cErrMsg2 = ''        
            END        
                           
            SET @nErrNo = 201264      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            GOTO Quit      
         END      
         /*      
         IF EXISTS (      
             SELECT 1 FROM dbo.OrderDetail OD WITH (NOLOCK)      
             OUTER APPLY (      
                 SELECT RefNo FROM dbo.PackDetail PD WITH (NOLOCK)      
                 JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNo = PD.PickSlipNo)       
                 WHERE OrderKey = OD.OrderKey       
                 AND   PD.SKU = OD.SKU       
             ) PD      
             WHERE StorerKey = @cStorerKey      
             AND OrderKey = @cOrderKey      
             AND Notes <> ''      
             AND RefNo = '')      
         BEGIN       
            SET @nErrNo = 0        
            SET @cErrMsg1 = rdt.rdtgetmessage( 201260, @cLangCode, 'DSP') -- ORDERS HAS NOT      
            SET @cErrMsg2 = rdt.rdtgetmessage( 201261, @cLangCode, 'DSP') -- UNDERGONE VAS      
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                  @cErrMsg1, @cErrMsg2        
            IF @nErrNo = 1        
            BEGIN        
               SET @cErrMsg1 = ''        
               SET @cErrMsg2 = ''        
            END        
                           
            SET @nErrNo = 201260      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            GOTO Quit      
         END      
         */      
         -- Disallow user to scan a new pallet for palletized customer if there is open pallet with same criteria      
         -- Requires 1 open pallet at a time for palletized customer      
         SET @cCheckOpenPalletizedPallet = rdt.RDTGetConfig( @nFunc, 'CheckOpenPalletizedPallet', @cStorerkey)        
         IF @cCheckOpenPalletizedPallet = '1' AND @cOrdPalletizedField <> ''        
         BEGIN      
            SELECT @c_ExecStatements = N'SELECT DISTINCT TOP 1 @cOpenPalletizedPlt = PD.PalletKey ' +       
                           ' FROM dbo.PalletDetail PD WITH (NOLOCK) '      
                         + ' JOIN dbo.ORDERS WITH (NOLOCK) ON ( PD.UserDefine01 = Orders.OrderKey AND PD.StorerKey = Orders.StorerKey) '      
                         + ' JOIN dbo.CODELKUP CL WITH (NOLOCK) ON ' +       
                           ' ( Orders.BillToKey = CL.Code AND Orders.StorerKey = CL.StorerKey)'                           
                         + ' WHERE PD.PalletKey <> @cPalletKey '      
                         + ' AND   CL.ListName = ''NOMIXPLSHP'' '      
                         + ' AND   PD.UserDefine03 = @cLane '      
                         + ' AND   Orders.StorerKey = @cStorerKey '      
                         + ' AND ' + @cOrdPalletizedField + ' = @cOrdChkField '      
                         + ' AND   PD.Status = ''0'''      
      
            SET @c_ExecArguments = N'@cPalletKey               NVARCHAR(20)'      
                                + ', @cLane                    NVARCHAR(30)'      
                                + ', @cStorerKey               NVARCHAR(15)'      
            + ', @cOrdChkField             NVARCHAR(100)'      
                                + ', @cOrdPalletizedField      NVARCHAR(30)'      
                                + ', @cOpenPalletizedPlt       NVARCHAR(20) OUTPUT'      
      
            EXEC sp_ExecuteSql   @c_ExecStatements      
                                 , @c_ExecArguments      
                                 , @cPalletKey      
                                 , @cLane       
                                 , @cStorerKey      
                                 , @cOrdChkField      
                                 , @cOrdPalletizedField      
                                 , @cOpenPalletizedPlt OUTPUT                                       
                                       
            IF ISNULL(@cOpenPalletizedPlt, '') <> ''      
            BEGIN       
               SET @nErrNo = 0        
               SET @cErrMsg1 = rdt.rdtgetmessage( 201266, @cLangCode, 'DSP') -- ERROR:      
               SET @cErrMsg2 = rdt.rdtgetmessage( 201267, @cLangCode, 'DSP') -- [PALLETIZED CUSTOMER]      
               SET @cErrMsg3 = rdt.rdtgetmessage( 201268, @cLangCode, 'DSP') -- CLOSE OR SCAN TO      
               SET @cErrMsg4 = @cOpenPalletizedPlt      
               SET @cErrMsg5 = rdt.rdtgetmessage( 201269, @cLangCode, 'DSP') -- FIRST      
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5        
               IF @nErrNo = 1        
               BEGIN        
                  SET @cErrMsg1 = ''        
                  SET @cErrMsg2 = ''      
                  SET @cErrMsg3 = ''        
                  SET @cErrMsg4 = ''        
                  SET @cErrMsg5 = ''        
               END        
                           
               SET @nErrNo = 201266      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
               GOTO Quit      
            END       
         END       
             
         IF EXISTS ( SELECT 1     
                     FROM dbo.Codelkup WITH (NOLOCK)      
                     WHERE ListName = 'LANECONFIG'      
                     AND   Code = 'NOMIXWAVE'      
                     AND   StorerKey = @cStorerKey    
                     AND   code2 = @cOrderType)    
            SET @nFilterOrdType = 1    
         ELSE    
          SET @nFilterOrdType = 0    
    
         SELECT @nLaneNoMixWave = Short FROM dbo.Codelkup WITH (NOLOCK)      
         WHERE ListName = 'LANECONFIG'      
         AND   Code = 'NOMIXWAVE'      
         AND   StorerKey = @cStorerKey      
         AND  (( @nFilterOrdType = 0 AND code2 = '') OR ( @nFilterOrdType = 1 AND code2 = @cOrderType))    
             
         IF EXISTS ( SELECT 1    
                     FROM dbo.Codelkup WITH (NOLOCK)      
                     WHERE ListName = 'LANECONFIG'      
                     AND   Code = 'NOMIXSHIPPER'      
                     AND   StorerKey = @cStorerKey    
                     AND   code2 = @cOrderType)    
            SET @nFilterOrdType = 1    
         ELSE    
          SET @nFilterOrdType = 0    
    
         SELECT @nLaneNoMixShipper = Short FROM dbo.Codelkup WITH (NOLOCK)      
         WHERE ListName = 'LANECONFIG'      
         AND   Code = 'NOMIXSHIPPER'      
         AND   StorerKey = @cStorerKey      
         AND   (( @nFilterOrdType = 0 AND code2 = '') OR ( @nFilterOrdType = 1 AND code2 = @cOrderType))    
             
         -- Not allowed to mix shipper or Wave in a lane      
         IF (@nLaneNoMixShipper = 1 OR @nLaneNoMixWave = 1)      
         BEGIN       
             SELECT TOP 1 @cLaneShipperKey = ShipperKey, @cLaneWaveKey = O.UserDefine09 FROM dbo.MBOL M WITH (NOLOCK)      
             JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON MD.MBOLKey = M.MBOLKey      
             JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = MD.OrderKey AND O.MBOLKey = M.MBOLKey      
             WHERE O.StorerKey = @cStorerKey      
             AND M.ExternMBOLKey = @cLane      
      
             SELECT @cOrdShipperKey = ShipperKey, @cOrdWaveKey = UserDefine09 FROM dbo.Orders WITH (NOLOCK)      
             WHERE OrderKey = @cOrderKey     -- To-be scanned order      
      
             IF @nLaneNoMixWave = 1       
             AND (ISNULL(@cLaneWaveKey, '') <> '' AND @cOrdWaveKey <> @cLaneWaveKey)      
             BEGIN      
               SET @nErrNo = 201270      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lane Mix Wave      
               GOTO Quit      
             END      
      
             IF @nLaneNoMixShipper = 1       
             AND (ISNULL(@cLaneShipperKey, '') <> '' AND @cOrdShipperKey <> @cLaneShipperKey)      
             BEGIN      
               SET @nErrNo = 201271      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lane Mix Shipper      
               GOTO Quit      
             END      
         END      
       
         IF EXISTS ( SELECT 1    
                     FROM dbo.Codelkup WITH (NOLOCK)      
                     WHERE ListName = 'LANECONFIG'      
                     AND   Code = 'NOMIXPLTCUSTOMER'      
                     AND   StorerKey = @cStorerKey      
                     AND   code2 = @cOrderType)    
            SET @nFilterOrdType = 1    
     ELSE    
          SET @nFilterOrdType = 0    
    
         SELECT @nLaneNoMixPltCustomer = Short FROM dbo.Codelkup WITH (NOLOCK)      
         WHERE ListName = 'LANECONFIG'      
         AND Code = 'NOMIXPLTCUSTOMER'      
         AND StorerKey = @cStorerKey      
         AND   (( @nFilterOrdType = 0 AND code2 = '') OR ( @nFilterOrdType = 1 AND code2 = @cOrderType))    
             
         -- Not allowed to mix palletized customer with normal orders in a lane      
         IF @nLaneNoMixPltCustomer = 1      
         BEGIN      
             SELECT @nOrdHasPltCustomer = CASE WHEN ISNULL( CL.Code, '') <> '' THEN 1 ELSE 0 END      
             FROM dbo.Orders O WITH (NOLOCK)      
             LEFT JOIN dbo.Codelkup CL WITH (NOLOCK) ON O.BillToKey = CL.Code AND O.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'        
             WHERE O.StorerKey = @cStorerKey        
             AND O.OrderKey = @cOrderKey      
      
             SELECT @nLaneHasPltCustomer = CASE WHEN ISNULL( CL.Code, '') <> '' THEN 1 ELSE 0 END        
             FROM dbo.PalletDetail PD WITH (NOLOCK)        
             JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.UserDefine01 = O.OrderKey AND PD.StorerKey = O.StorerKey)         
             LEFT JOIN dbo.Codelkup CL WITH (NOLOCK) ON O.BillToKey = CL.Code AND O.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'        
             WHERE O.StorerKey = @cStorerKey        
             AND PD.UserDefine03 = @cLane      
      
             IF @@ROWCOUNT > 0 AND @nLaneHasPltCustomer <> @nOrdHasPltCustomer      
             BEGIN      
               SET @nErrNo = 0        
               SET @cErrMsg1 = rdt.rdtgetmessage( 201272, @cLangCode, 'DSP') -- NOT ALLOW TO MIX       
               SET @cErrMsg2 = rdt.rdtgetmessage( 201273, @cLangCode, 'DSP') -- PALLETIZED CUSTOMER      
               SET @cErrMsg3 = rdt.rdtgetmessage( 201274, @cLangCode, 'DSP') -- WITH NON PALLETIZED      
               SET @cErrMsg4 = rdt.rdtgetmessage( 201275, @cLangCode, 'DSP') -- IN LANE      
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                     @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4        
               IF @nErrNo = 1        
               BEGIN        
                  SET @cErrMsg1 = ''        
                  SET @cErrMsg2 = ''      
                  SET @cErrMsg3 = ''        
                  SET @cErrMsg4 = ''        
               END        
                           
               SET @nErrNo = 201272      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
               GOTO Quit      
             END      
         END      

         -- (james02)
         -- Only when orders.buyerpo not exists in current lane then only validate
         IF NOT EXISTS( SELECT 1
                        FROM dbo.ORDERS O WITH (NOLOCK)
                        JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON ( O.OrderKey = MD.OrderKey)
                        JOIN dbo.MBOL M WITH (NOLOCK) ON ( MD.MbolKey = M.MbolKey)
         	            WHERE M.ExternMBOLKey = @cLane
                        AND   O.BuyerPO = @cBuyerPO)
         BEGIN
            SELECT @cAllowedLaneBuyerPO = UDF05
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE ListName = 'NOMIXPLSHP'
            AND   Code = @cBillToKey
            AND   StorerKey = @cStorerKey
         
            IF ISNULL( @cAllowedLaneBuyerPO, '') <> ''
            BEGIN
         	   SET @nAllowedLaneBuyerPO = CAST( @cAllowedLaneBuyerPO AS INT)
         	
         	   SELECT @nLaneBuyerPO = COUNT( DISTINCT O.BuyerPO)
         	   FROM dbo.PALLETDETAIL PD WITH (NOLOCK)
         	   JOIN dbo.MBOL M WITH (NOLOCK) ON ( PD.UserDefine03 = M.ExternMBOLKey)
               JOIN dbo.ORDERS O WITH (NOLOCK) ON ( M.MBOLKey = O.MBOLKey)
         	   WHERE M.ExternMBOLKey = @cLane

         	   IF @nLaneBuyerPO > 0 AND ( @nLaneBuyerPO + 1 > @nAllowedLaneBuyerPO)
         	   BEGIN
                  SET @nErrNo = 0      
                  SET @cErrMsg1 = rdt.rdtgetmessage( 201277, @cLangCode, 'DSP') -- EXCEED MAX BUYERPO     
                  SET @cErrMsg2 = rdt.rdtgetmessage( 201278, @cLangCode, 'DSP') -- PAR LANE    
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,     
                        @cErrMsg1, @cErrMsg2      
                  IF @nErrNo = 1      
                  BEGIN      
                     SET @cErrMsg1 = ''      
                     SET @cErrMsg2 = ''    
                  END      
                         
                  SET @nErrNo = 201277    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')    
                  GOTO Quit    
         	   END
            END
         END
      END      
   END      
         
   IF @nStep = 6 -- Pallet Dimesion      
   BEGIN      
      IF @nInputKey = 1 -- ENTER      
      BEGIN      
       --UDF03 = empty pallet height      
       SELECT       
          @cUDF03 = UDF03      
       FROM dbo.CODELKUP WITH (NOLOCK)       
       WHERE LISTNAME = 'ADIPLTDM'      
       AND   Storerkey = @cStorerkey      
       AND   CHARINDEX( Code, @cPalletKey) > 0      
      
         IF @@ROWCOUNT = 0      
         BEGIN      
          SELECT       
             @cUDF03 = UDF03      
          FROM dbo.CODELKUP WITH (NOLOCK)       
          WHERE LISTNAME = 'ADIPLTDM'      
          AND   Storerkey = @cStorerkey      
          AND   CODE = 'DEFAULT'      
         END      
               
         SELECT @cHeight = Value FROM @tExtValidVar WHERE Variable = '@cHeight'                      
      
       SET @fHeight = CAST( @cHeight AS FLOAT)      
      
         SELECT       
             --@fMinHeight = CAST(MIN(HEIGHT) AS INT) * (COUNT(1) / 4), --'Estimated Min Height (CM)',       
             --@fMaxHeight = CAST(MAX(HEIGHT) AS INT) * (COUNT(1) / 4)  --'Estimated Max Height (CM)'       
            @fMinHeight =  CAST( @cUDF03 AS FLOAT) + CAST(MIN(Height) AS FLOAT) * (CASE WHEN CEILING(COUNT(1) / 4.0) > 0 THEN CEILING(COUNT(1) / 4.0) ELSE 1 END), --'Estimated Min Height (CM)'      
            @fMaxHeight =  CAST( @cUDF03 AS FLOAT) + CAST(MAX(Height) AS FLOAT) * (CASE WHEN CEILING(COUNT(1) / 4.0) > 0 THEN CEILING(COUNT(1) / 4.0) ELSE 1 END)  --'Estimated Max Height (CM)'         
         FROM dbo.PALLETDETAIL PLD WITH (NOLOCK)      
         CROSS APPLY (      
         SELECT DISTINCT LABELNO, LENGTH, WIDTH, HEIGHT FROM dbo.PACKDETAIL PD WITH (NOLOCK)       
         JOIN dbo.PACKINFO PI WITH (NOLOCK) ON PI.PICKSLIPNO = PD.PICKSLIPNO AND PI.CartonNo = PD.CartonNo      
         WHERE PD.LABELNO = PLD.CASEID       
         AND PLD.STORERKEY = PD.STORERKEY       
         ) PD      
         WHERE PLD.STORERKEY = @cStorerKey      
         AND PalletKey = @cPalletKey      
         GROUP BY PALLETKEY      
     
   /*WC01 Start*/  
         SET @fORIMinHeight = @fMinHeight  
         SET @fORIMaxHeight = @fMaxHeight  
     
         SET @fMinHeight = CAST(CAST(@fORIMinHeight AS NVARCHAR) AS FLOAT)  
         SET @fMaxHeight = CAST(CAST(@fORIMaxHeight AS NVARCHAR) AS FLOAT)  
   /*WC01 End*/     
      
         IF @fHeight NOT BETWEEN @fMinHeight AND @fMaxHeight      
         BEGIN      
            SET @nErrNo = 0        
            SET @cErrMsg1 = rdt.rdtgetmessage( 201258, @cLangCode, 'DSP') -- SCANNED HEIGHT      
            SET @cErrMsg2 = rdt.rdtgetmessage( 201259, @cLangCode, 'DSP') -- NOT IN RANGE      
            SET @cErrMsg3 = ''      
            SET @cErrMsg4 = ''        
            SET @cErrMsg5 = ''      
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,       
                  @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5        
            IF @nErrNo = 1        
            BEGIN        
               SET @cErrMsg1 = ''        
               SET @cErrMsg2 = ''        
               SET @cErrMsg3 = ''        
               SET @cErrMsg4 = ''      
               SET @cErrMsg5 = ''      
  END        
                           
            SET @nErrNo = 201259      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            GOTO Quit      
         END       
      
      END      
   END      
         
   Quit:      
END      

GO