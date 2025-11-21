SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/                
/* Store procedure: isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE             */                
/* Creation Date: 21-JUN-2018                                           */  
/* Copyright: IDS                                                       */  
/* Written by: AlexKeoh                                                 */  
/*                                                                      */  
/* Purpose: Pass Incoming Request String For Interface                  */  
/*                                                                      */  
/* Input Parameters:  @b_Debug            - 0                           */  
/*                    @c_Format           - 'JSON'                      */  
/*                    @c_UserID           - 'UserName'                  */  
/*                    @c_OperationType    - 'Operation'                 */  
/*                    @c_RequestString    - ''                          */  
/*                    @b_Debug            - 0                           */  
/*                                                                      */  
/* Output Parameters: @b_Success          - Success Flag    = 0         */  
/*                    @c_ErrNo            - Error No        = 0         */  
/*                    @c_ErrMsg           - Error Message   = ''        */  
/*                    @c_ResponseString   - ResponseString  = ''        */  
/*                                                                      */  
/* Called By: LeafAPIServer - isp_Generic_WebAPI_Request                */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Purposes                                        */  
/* 2018-06-21  Alex     Initial - Jira Ticket #WMS-5274                 */  
/* 2018-08-15  TKLIM    Set @n_QtyReceived = 0 before start using       */  
/*                      Added @b_Debug log for better tracking          */  
/************************************************************************/      
CREATE PROC [dbo].[isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE](  
     @b_Debug           INT            = 0  
   , @c_Format          VARCHAR(10)    = ''  
   , @c_UserID          NVARCHAR(256)  = ''  
   , @c_OperationType   NVARCHAR(60)   = ''  
   , @c_RequestString   NVARCHAR(MAX)  = ''  
   , @b_Success         INT            = 0   OUTPUT  
   , @n_ErrNo           INT            = 0   OUTPUT  
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT  
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF   
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue                    INT  
         , @n_StartCnt                    INT  
         , @c_ExecStatements              NVARCHAR(MAX)  
         , @c_ExecArguments               NVARCHAR(2000)  
  
         , @c_Application                 NVARCHAR(50)  
         , @c_MessageType                 NVARCHAR(10)  
  
         , @c_Facility                    NVARCHAR(5)  
         , @c_StorerKey                   NVARCHAR(15)  
  
         , @c_pallet_code                 NVARCHAR(18)  
         , @c_transaction_id              NVARCHAR(32)  
         , @c_sku_code                    NVARCHAR(20)  
         , @c_status                      NVARCHAR(5)  
         , @c_owner_code                  NVARCHAR(16)  
         , @n_sku_receive_amount          INT  
         , @n_sku_planned_amount          INT  
         , @n_sku_missing_amount          INT  
  
         , @c_Lot                         NVARCHAR(10)  
         , @c_FromLoc                     NVARCHAR(10)  
         , @c_FromLocPickZone             NVARCHAR(10)  
         , @c_ToRobotLoc                  NVARCHAR(10)  
         , @c_ToRobotHOLDLoc              NVARCHAR(10)  
         , @n_CurrentLLIQTY               INT  
         , @c_ListName_ROBOTSTR           NVARCHAR(10)  
         , @n_Exists                      INT  
         , @n_QtyNotReceived              INT  
         , @n_QtyReceived                 INT  
  
   SET @n_Continue                        = 1  
   SET @n_StartCnt                        = @@TRANCOUNT  
   SET @b_Success                         = 1  
   SET @n_ErrNo                           = 0  
   SET @c_ErrMsg                          = ''  
   SET @c_ResponseString                  = ''  
     
   SET @c_Application                     = 'GEEK+_RECEIVING_RESPONSE_IN'  
   SET @c_MessageType                     = 'WS_IN'  
  
   SET @c_Facility                        = ''  
   SET @c_StorerKey                       = ''  
  
   SET @c_pallet_code                     = ''  
   SET @c_sku_code                        = ''  
   SET @c_status                          = ''  
   SET @c_owner_code                      = ''  
   SET @n_sku_receive_amount              = 0  
   SET @n_sku_planned_amount              = 0  
   SET @n_sku_missing_amount              = 0  
  
   SET @c_Lot                             = ''  
   SET @c_FromLoc                         = ''  
   SET @c_ToRobotLoc                      = ''  
   SET @c_ToRobotHOLDLoc                  = ''  
   SET @n_CurrentLLIQTY                   = 0  
   SET @c_ListName_ROBOTSTR               = 'ROBOTSTR'  
   SET @n_QtyNotReceived                  = 0   
   SET @n_QtyReceived                     = 0   

   --IF OBJECT_ID('tempdb..#TEMP_Geek_PalletList') IS NOT NULL  
   --DROP TABLE #TEMP_Geek_PalletList  
  
   --CREATE TABLE #TEMP_Geek_PalletList(  
   --   receipt_code      NVARCHAR(32),  
   --   pallet_id         NVARCHAR(18),  
   --   [status]          INT  
   --)  
  
   IF NOT ISJSON(@c_RequestString) > 0  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 210000  
      SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - invalid JSON request..'  
      GOTO QUIT  
   END  
  
   IF OBJECT_ID('tempdb..#TEMP_Geek_PalletSKUList') IS NOT NULL  
   DROP TABLE #TEMP_Geek_PalletSKUList  
  
   CREATE TABLE #TEMP_Geek_PalletSKUList(  
      pallet_code       NVARCHAR(18),  
      transaction_id    NVARCHAR(32),  
      sku_code          NVARCHAR(20),  
      [status]          NVARCHAR(5),  
      owner_code        NVARCHAR(16),  
      amount            INT,  
      planned_amount    INT  
   )  
  
   INSERT INTO #TEMP_Geek_PalletSKUList ( pallet_code, transaction_id, sku_code, [status], owner_code, amount, planned_amount )  
   SELECT Receipt.pallet_code, Receipt.transaction_id, LSKU.sku_code, Receipt.[status], LSKU.owner_code, LSKU.amount, LSKU.planned_amount  
   FROM OPENJSON(@c_RequestString, '$.body.receipt_list')  
   WITH (  
      receipt_code         NVARCHAR(50)      '$.receipt_code',  
      pallet_code          NVARCHAR(50)      '$.pallet_code',  
      [status]             NVARCHAR(5)       '$.status',  
      transaction_id       NVARCHAR(32)      '$.transaction_id',  
      [sku_list]           NVARCHAR(MAX) As JSON-- '$.sku_list'  
   ) As Receipt  
   CROSS APPLY   
   OPENJSON (Receipt.sku_list)  
   with  
   (  
      sku_code             NVARCHAR(30)      '$.sku_code',  
      owner_code           NVARCHAR(30)      '$.owner_code',  
      amount               INT               '$.amount',  
      planned_amount       INT               '$.plan_amount'  
   ) as LSKU  
  
   IF @b_Debug = 1  
   BEGIN  
      SELECT * FROM #TEMP_Geek_PalletSKUList  
      Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - SELECT * FROM #TEMP_Geek_PalletSKUList'
   END  
  

   IF NOT EXISTS ( SELECT 1 FROM #TEMP_Geek_PalletSKUList WHERE ISNULL(RTRIM(pallet_code), '') <> '')  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_ErrNo = 210001  
      SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - must submit at least one pallet_code..'  
      GOTO QUIT  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      BEGIN TRAN  
      -- Loop each pallet  
      DECLARE GEEKPLUS_RECEIVEIN_PALLETLIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT pallet_code,  transaction_id, [status]  
         FROM #TEMP_Geek_PalletSKUList  
         WHERE ISNULL(RTRIM(pallet_code), '') <> ''  
         GROUP BY pallet_code, transaction_id, [status]  
      OPEN GEEKPLUS_RECEIVEIN_PALLETLIST  
        
      FETCH NEXT FROM GEEKPLUS_RECEIVEIN_PALLETLIST INTO @c_pallet_code, @c_transaction_id, @c_status  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         -- Loop each pallet's sku  
         DECLARE GEEKPLUS_RECEIVEIN_SKULIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT sku_code, amount, owner_code, planned_amount  
            FROM #TEMP_Geek_PalletSKUList  
            WHERE ISNULL(RTRIM(pallet_code), '') = @c_pallet_code  
         OPEN GEEKPLUS_RECEIVEIN_SKULIST  
           
         FETCH NEXT FROM GEEKPLUS_RECEIVEIN_SKULIST INTO @c_sku_code, @n_sku_receive_amount, @c_owner_code, @n_sku_planned_amount  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  

            IF @b_Debug = 1  
            BEGIN  
               Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @c_sku_code=' + @c_sku_code + '; @n_sku_receive_amount=' + CONVERT(NVARCHAR, @n_sku_receive_amount) + '; @c_owner_code=' + @c_owner_code + '; @n_sku_planned_amount=' + CONVERT(NVARCHAR, @n_sku_planned_amount)
            END  

            SELECT @c_StorerKey = '', @n_Exists = 0  
            SELECT @n_Exists = (1), @c_StorerKey = Code  
            FROM dbo.Codelkup WITH (NOLOCK)  
            WHERE ListName = @c_ListName_ROBOTSTR  
            AND Short = @c_owner_code  
  
            IF @n_Exists = 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @n_ErrNo = 210002  
               SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - cannot lookup storerkey with owner_code(' + @c_owner_code + ')..'  
               GOTO QUIT  
            END  
  
            SELECT @n_Exists = 0, @c_Lot = '', @c_FromLoc = '', @n_CurrentLLIQTY = 0, @c_Facility = '', @c_FromLocPickZone = ''  
            SELECT @n_Exists = (1)  
                 --, @c_Lot = LLI.Lot  
                 --, @c_FromLoc = LLI.Loc  
                 --, @n_CurrentLLIQTY = LLI.Qty  
                 --, @c_Facility = L.Facility  
                 --, @c_FromLocPickZone = L.PickZone  
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
            INNER JOIN dbo.Loc L WITH (NOLOCK) ON ( L.Loc = LLI.Loc AND L.LocationType = 'ROBOTSTG' )  
            WHERE LLI.Id = @c_pallet_code   
            AND LLI.StorerKey = @c_StorerKey   
            AND LLI.SKU = @c_sku_code  
            AND LLI.Qty > 0  
              
            IF @n_Exists = 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @n_ErrNo = 210003  
               SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - no LOTxLOCxID found Id(' + @c_pallet_code + ')..'  
               GOTO QUIT  
            END  
  
            SET @n_sku_missing_amount = 0  
            SET @n_sku_missing_amount = (@n_sku_planned_amount - @n_sku_receive_amount)  
  


            DECLARE GEEKPLUS_RECEIVEIN_LLILIST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT LLI.Lot  
                    , LLI.Loc  
                    , LLI.Qty  
                    , L.Facility  
                    , L.PickZone  
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)  
               INNER JOIN dbo.Loc L WITH (NOLOCK) ON ( L.Loc = LLI.Loc AND L.LocationType = 'ROBOTSTG' )  
               WHERE LLI.Id = @c_pallet_code   
               AND LLI.StorerKey = @c_StorerKey   
               AND LLI.SKU = @c_sku_code  
               AND LLI.Qty > 0  
            OPEN GEEKPLUS_RECEIVEIN_LLILIST  
           
            FETCH NEXT FROM GEEKPLUS_RECEIVEIN_LLILIST INTO @c_Lot, @c_FromLoc, @n_CurrentLLIQTY, @c_Facility, @c_FromLocPickZone  
            WHILE @@FETCH_STATUS <> -1  
            BEGIN 
            
               --IF @b_Debug = 1  
               --BEGIN  
               --   Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @n_sku_receive_amount=' + CONVERT(NVARCHAR, @n_sku_receive_amount) 
               --   Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @n_sku_missing_amount=' + CONVERT(NVARCHAR, @n_sku_missing_amount) 
               --END  

             
               IF @n_sku_receive_amount <> 0 OR @n_sku_missing_amount <> 0  
               BEGIN  


                  --Get ROBOT Location  
                  SELECT @c_ToRobotLoc = Loc  
                  FROM [dbo].[LOC] WITH (NOLOCK)  
                  WHERE Facility = @c_Facility  
                  AND LocationCategory='ROBOT'   
                  AND LocationType='DYNPPICK'  
                  And PickZone = @c_FromLocPickZone  
  
                  IF ISNULL(RTRIM(@c_ToRobotLoc), '') = ''  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_ErrNo = 210004  
                     SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - Robot Location is not setup..'  
                     GOTO QUIT  
                  END  
  
                  SELECT @n_QtyReceived = 0, @n_QtyNotReceived = 0  

                  IF @n_sku_receive_amount > 0  
                  BEGIN  
                     SET @n_QtyReceived = CASE WHEN (@n_sku_receive_amount >= @n_CurrentLLIQTY) THEN @n_CurrentLLIQTY  
                                       ELSE @n_sku_receive_amount END  
                     SET @n_sku_receive_amount = @n_sku_receive_amount - @n_QtyReceived  
                  END  
                    

                  IF @n_sku_missing_amount > 0 AND (@n_CurrentLLIQTY - @n_QtyReceived) > 0  
                  BEGIN  
                     -- (currentqty - qtyreceived) >= missing  ( (currentqty - qtyreceived) - missing )  
                     -- (currentqty - qtyreceived)  
                     SET @n_QtyNotReceived = CASE WHEN (@n_sku_missing_amount > (@n_CurrentLLIQTY - @n_QtyReceived))   
                                                THEN (@n_CurrentLLIQTY - @n_QtyReceived)  
                                             ELSE @n_sku_missing_amount END  
  
                     SET @n_sku_missing_amount = @n_sku_missing_amount - @n_QtyNotReceived  
                  END  
                    
                  IF @b_Debug = 1  
                  BEGIN  
                     Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @n_sku_receive_amount=' + CONVERT(NVARCHAR, @n_sku_receive_amount) 
                     Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @n_sku_missing_amount=' + CONVERT(NVARCHAR, @n_sku_missing_amount) 
                     Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @n_CurrentLLIQTY=' + CONVERT(NVARCHAR, @n_CurrentLLIQTY) 
                     Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @n_QtyReceived=' + CONVERT(NVARCHAR, @n_QtyReceived) 
                     Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - @n_QtyNotReceived=' + CONVERT(NVARCHAR, @n_QtyNotReceived) 
                  END  


                  IF @n_QtyReceived > 0  
                  BEGIN  
                     IF @b_Debug = '1'
                     BEGIN
                        Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - Moving @n_QtyReceived ' +  CONVERT(NVARCHAR, @n_QtyReceived) + ' Qty of ' + @c_sku_code + ' on Pallet <' + @c_pallet_code + '> to Pallet '''' from ' + @c_FromLoc + ' to ' + @c_ToRobotLoc
                     END

                     EXEC nspItrnAddMove  
                        @n_ItrnSysId      = NULL                                         
                      , @c_StorerKey      = @c_StorerKey                         -- @c_StorerKey     
                      , @c_Sku            = @c_sku_code                          -- @c_Sku           
                      , @c_Lot            = @c_Lot                               -- @c_Lot           
                      , @c_FromLoc        = @c_FromLoc                           -- @c_FromLoc       
                      , @c_FromID         = @c_pallet_code                       -- @c_FromID        
                      , @c_ToLoc          = @c_ToRobotLoc                        -- @c_ToLoc         
                      , @c_ToID           = ''                                   -- @c_ToID          
                      , @c_Status         = '0'                                  -- @c_Status        
                      , @c_lottable01     = ''                                   -- @c_lottable01    
                      , @c_lottable02     = ''                                   -- @c_lottable02    
                      , @c_lottable03     = ''                                   -- @c_lottable03    
                      , @d_lottable04     = NULL                                 -- @d_lottable04    
                      , @d_lottable05     = NULL                                 -- @d_lottable05    
                      , @c_lottable06     = ''                                   -- @c_lottable06    
                      , @c_lottable07     = ''                                   -- @c_lottable07    
                      , @c_lottable08     = ''                                   -- @c_lottable08    
                      , @c_lottable09     = ''                                   -- @c_lottable09    
                      , @c_lottable10     = ''                                   -- @c_lottable10    
                      , @c_lottable11     = ''                                   -- @c_lottable11    
                      , @c_lottable12     = ''                                   -- @c_lottable12    
                      , @d_lottable13     = NULL                                 -- @d_lottable13    
                      , @d_lottable14     = NULL                                 -- @d_lottable14    
                      , @d_lottable15     = NULL                                 -- @d_lottable15    
                      , @n_casecnt        = 0                                    -- @n_casecnt       
                      , @n_innerpack      = 0                                    -- @n_innerpack     
                      , @n_qty            = @n_QtyReceived                       -- @n_qty           
                      , @n_pallet         = 0                                    -- @n_pallet        
                      , @f_cube           = 0                                    -- @f_cube          
                      , @f_grosswgt       = 0                                    -- @f_grosswgt      
                      , @f_netwgt         = 0                                    -- @f_netwgt        
                      , @f_otherunit1     = 0                                    -- @f_otherunit1    
                      , @f_otherunit2     = 0                                    -- @f_otherunit2    
                      , @c_SourceKey      = @c_transaction_id                    -- @c_SourceKey  
                      , @c_SourceType     = 'Robot Geek+ RECEIVING IN Move'      -- @c_SourceType  
                      , @c_PackKey        = ''                                   -- @c_PackKey       
                      , @c_UOM            = ''                                   -- @c_UOM           
                      , @b_UOMCalc        = 0                                    -- @b_UOMCalc       
                      , @d_EffectiveDate  = NULL                                 -- @d_EffectiveD    
                      , @c_itrnkey        = ''                                   -- @c_itrnkey       
                      , @b_Success        = @b_Success   OUTPUT                  -- @b_Success     
                      , @n_err            = @n_ErrNo     OUTPUT                -- @n_err         
                      , @c_errmsg         = @c_ErrMsg    OUTPUT                  -- @c_errmsg      
                      , @c_MoveRefKey     = ''                                   -- @c_MoveRefKey    
                    
                     IF @b_Success <> 1  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @n_ErrNo = 210005  
                        SET @c_ErrMsg = 'Failed to move inventory to ROBOT Location..'  
                        GOTO QUIT  
                     END  
                  END  
  
                  -- Move all receive amount to robot location  
                  IF @n_QtyNotReceived > 0  
                  BEGIN  
                     --Get ROBOT HOLD Location  
                     SELECT @c_ToRobotHOLDLoc = Loc  
                     FROM [dbo].[LOC] WITH (NOLOCK)  
                     WHERE Facility = @c_Facility  
                     AND LocationCategory='ROBOT'   
                     AND LocationType='ROBOTHOLD'  
                     AND PickZone = @c_FromLocPickZone  
  
                     IF ISNULL(RTRIM(@c_ToRobotHOLDLoc), '') = ''  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @n_ErrNo = 210006  
                        SET @c_ErrMsg = CONVERT(NVARCHAR, @n_ErrNo) + ' - Robot HOLD Location is not setup..'  
                        GOTO QUIT  
                     END  

                     IF @b_Debug = '1'
                     BEGIN
                        Print 'isp_WebAPI_GEEKPLUSRBT_RECEIVE_RESPONSE - Moving @n_QtyNotReceived ' +  CONVERT(NVARCHAR, @n_QtyNotReceived) + ' Qty of ' + @c_sku_code + ' on Pallet <' + @c_pallet_code + '> to Pallet <' + @c_pallet_code + '> from ' + @c_FromLoc + ' to ' + @c_ToRobotHOLDLoc
                     END

                     --Move received amount to ROBOT LOC  
                     EXEC nspItrnAddMove  
                        @n_ItrnSysId      = NULL                                         
                      , @c_StorerKey      = @c_StorerKey                         -- @c_StorerKey     
                      , @c_Sku            = @c_sku_code                          -- @c_Sku           
                      , @c_Lot            = @c_Lot                               -- @c_Lot           
                      , @c_FromLoc        = @c_FromLoc                           -- @c_FromLoc       
                      , @c_FromID         = @c_pallet_code                       -- @c_FromID        
                      , @c_ToLoc          = @c_ToRobotHOLDLoc                    -- @c_ToLoc         
                      , @c_ToID           = @c_pallet_code                       -- @c_ToID          
                      , @c_Status         = '0'                                  -- @c_Status        
                      , @c_lottable01     = ''                                   -- @c_lottable01    
                      , @c_lottable02     = ''                                   -- @c_lottable02    
                      , @c_lottable03     = ''                                   -- @c_lottable03    
                      , @d_lottable04     = NULL                                 -- @d_lottable04    
                      , @d_lottable05     = NULL                                 -- @d_lottable05    
                      , @c_lottable06     = ''                                   -- @c_lottable06    
                      , @c_lottable07     = ''                                   -- @c_lottable07    
                      , @c_lottable08     = ''                                   -- @c_lottable08    
                      , @c_lottable09     = ''                                   -- @c_lottable09    
                      , @c_lottable10     = ''                                   -- @c_lottable10    
                      , @c_lottable11     = ''                                   -- @c_lottable11    
                      , @c_lottable12     = ''                                   -- @c_lottable12    
                      , @d_lottable13     = NULL                                 -- @d_lottable13    
                      , @d_lottable14     = NULL                                 -- @d_lottable14    
                      , @d_lottable15     = NULL                                 -- @d_lottable15    
                      , @n_casecnt        = 0                                    -- @n_casecnt       
                      , @n_innerpack      = 0                                    -- @n_innerpack     
                      , @n_qty            = @n_QtyNotReceived                    -- @n_qty           
                      , @n_pallet         = 0                                    -- @n_pallet        
                      , @f_cube           = 0                                    -- @f_cube          
                      , @f_grosswgt       = 0                                    -- @f_grosswgt      
                      , @f_netwgt         = 0                                    -- @f_netwgt        
                      , @f_otherunit1     = 0                                    -- @f_otherunit1    
                      , @f_otherunit2     = 0                                    -- @f_otherunit2    
                      , @c_SourceKey      = @c_transaction_id                    -- @c_SourceKey  
                      , @c_SourceType     = 'Robot Geek+ RECEIVING IN Move'      -- @c_SourceType  
                      , @c_PackKey        = ''                                   -- @c_PackKey       
                      , @c_UOM            = ''                                   -- @c_UOM           
                      , @b_UOMCalc        = 0                                    -- @b_UOMCalc       
                      , @d_EffectiveDate  = NULL                                 -- @d_EffectiveD    
                      , @c_itrnkey        = ''                                   -- @c_itrnkey       
                      , @b_Success        = @b_Success   OUTPUT                  -- @b_Success     
                      , @n_err            = @n_ErrNo     OUTPUT                  -- @n_err         
                      , @c_errmsg         = @c_ErrMsg    OUTPUT                  -- @c_errmsg      
                      , @c_MoveRefKey     = ''                                   -- @c_MoveRefKey    
                       
                     IF @b_Success <> 1  
                     BEGIN  
                        SET @n_Continue = 3  
                        SET @n_ErrNo = 210007  
                        SET @c_ErrMsg = 'Failed to move inventory to ROBOT HOLD Location..'  
                        GOTO QUIT  
                     END  
                  END --IF @n_QtyNotReceived > 0  
               END  
  
               FETCH NEXT FROM GEEKPLUS_RECEIVEIN_LLILIST INTO @c_Lot, @c_FromLoc, @n_CurrentLLIQTY, @c_Facility, @c_FromLocPickZone  
            END  
            CLOSE GEEKPLUS_RECEIVEIN_LLILIST  
            DEALLOCATE GEEKPLUS_RECEIVEIN_LLILIST  
  
            FETCH NEXT FROM GEEKPLUS_RECEIVEIN_SKULIST INTO @c_sku_code, @n_sku_receive_amount, @c_owner_code, @n_sku_planned_amount  
         END  
         CLOSE GEEKPLUS_RECEIVEIN_SKULIST  
         DEALLOCATE GEEKPLUS_RECEIVEIN_SKULIST  
  
         FETCH NEXT FROM GEEKPLUS_RECEIVEIN_PALLETLIST INTO @c_pallet_code, @c_transaction_id, @c_status  
      END  
      CLOSE GEEKPLUS_RECEIVEIN_PALLETLIST  
      DEALLOCATE GEEKPLUS_RECEIVEIN_PALLETLIST  
   END  
  
     
   QUIT:  
  
   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_RECEIVEIN_PALLETLIST') in (0 , 1)    
   BEGIN    
      CLOSE GEEKPLUS_RECEIVEIN_PALLETLIST    
      DEALLOCATE GEEKPLUS_RECEIVEIN_PALLETLIST    
   END  
  
   IF CURSOR_STATUS('LOCAL' , 'GEEKPLUS_RECEIVEIN_SKULIST') in (0 , 1)    
   BEGIN    
      CLOSE GEEKPLUS_RECEIVEIN_SKULIST    
      DEALLOCATE GEEKPLUS_RECEIVEIN_SKULIST    
   END  
     
   IF @n_Continue = 3 AND @n_ErrNo <> 0  
   BEGIN  
      --SET @b_Success = 0        
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1   
      BEGIN                 
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartCnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END     
      --RETURN        
   END        
   ELSE        
   BEGIN        
      --SELECT @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      --RETURN        
   END  
  
   SET @c_ResponseString = ISNULL(RTRIM(  
      (  
         SELECT   
            CASE WHEN @n_ErrNo > 0 THEN '400' ELSE '200' END As 'header.msgCode'  
          , CASE WHEN @n_ErrNo > 0 THEN 'Error : ' + @c_ErrMsg   
               ELSE N'Process with Success' END As 'header.message'  
          , CONVERT(BIT, CASE WHEN @n_ErrNo > 0 THEN 0 ELSE 1 END) As 'body.success'  
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER  
      )  
   ), '')  
  
   --Insert log to TCPSocket_INLog  
   INSERT INTO dbo.TCPSOCKET_INLOG ( [Application], MessageType, ErrMsg, [Data], MessageNum, StorerKey, ACKData, [Status] )  
   VALUES ( @c_Application, @c_MessageType, @c_ErrMsg, @c_RequestString, '', @c_StorerKey, @c_ResponseString, '9' )  
  
   --Build Custom Response  
   SELECT @n_ErrNo = 0, @b_Success = 1, @c_ErrMsg = ''  
  
   RETURN  
END -- Procedure    

GO