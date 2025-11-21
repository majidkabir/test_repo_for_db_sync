SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: isp_PrePostallocate_Process                            */
/* Creation Date:                                                          */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5745 Standard Pre/Post Allocation Process                  */
/*                                                                         */
/* Called By: Allocation                                                   */
/*                                                                         */
/* PVCS Version: 1.3                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 10/10/2018   NJOW01    1.0   WMS-6435 able to run discrete allocation   */
/*                              before load/wave conso allocate. Usually   */
/*                              UOM 6,7 Pickcode will skip for discrete    */
/*                              and only allocate after conso              */
/* 03/12/2019   NJOW02    1.1   WMS-11282 able to run discrete alllocation */
/*                              after load/wave conso allocate.            */
/* 08-Jan-2020  NJOW03    1.2   WMS-10420 add strategykey parameter        */
/* 12-Jan-2023  NJOW04    1.3   WMS-19078 add @c_ConsoUnitByUCCNo option   */
/***************************************************************************/

CREATE   PROC [dbo].[isp_PrePostallocate_Process] 
   @c_Orderkey        NVARCHAR(10) = '', 
   @c_Loadkey         NVARCHAR(10) = '',
   @c_Wavekey         NVARCHAR(10) = '',
   @c_Mode            NVARCHAR(10) = '',  -- PRE/POST 
   @c_ExtendParms     NVARCHAR(250) = '',  
   @c_StrategyKeyParm NVARCHAR(10) = '',  --NJOW03 
   @b_Success         INT = 1            OUTPUT,
   @n_Err             INT = 0            OUTPUT, 
   @c_ErrMsg          NVARCHAR(250) = '' OUTPUT 
AS 
BEGIN
   DECLARE @n_StartTCnt                   INT,
           @n_Continue                    INT,
           @c_SuperOrderFlag              NVARCHAR(1),
           @c_Storerkey                   NVARCHAR(15),
           @c_Facility                    NVARCHAR(5),
           @c_AllocationType              NVARCHAR(20), --DISCRETE, LOADCONSO, WAVECONSO
           @c_AllocateFrom                NVARCHAR(20), --ORDER, LOADPLAN, WAVE
           @c_LoadConsoAllocation         NVARCHAR(30),
           @c_TempUOMofConso              NVARCHAR(10),
           @n_SeqNo                       INT,
           @c_Orderkey2                   NVARCHAR(10),
           @c_Loadkey2                    NVARCHAR(10),
           @c_Extendparms2                NVARCHAR(250) 
   
   DECLARE @c_PostAllocIdentifyConsoUnit  NVARCHAR(30),
           @c_option1                     NVARCHAR(50),
           @c_option2                     NVARCHAR(50),
           @c_option3                     NVARCHAR(50),
           @c_option4                     NVARCHAR(50),
           @c_option5                     NVARCHAR(4000),
           @c_DiscreteAllocB4WaveConso    NVARCHAR(10),
           @c_DiscreteAllocB4LoadConso    NVARCHAR(10),
           @c_LoadConsoAllocB4WaveConso   NVARCHAR(10)
                                         
   DECLARE @c_UOM                         NVARCHAR(10), 
           @c_GroupFieldList              NVARCHAR(2000),
           @c_ConsoGroupFieldList         NVARCHAR(2000),
           @c_SQLCondition                NVARCHAR(2000),
           @c_CaseCntByUCC                NVARCHAR(10),
           @c_PickMethodOfConso           NVARCHAR(1),
           @c_UOMOfConso                  NVARCHAR(10),
           @c_ConsolidatePieceProcess     NVARCHAR(5), 
           @c_IdentifyConsoUnitProcess    NVARCHAR(5),
           @c_ConsoUnitByUCCNo            NVARCHAR(5)  --NJOW04
   
   --NJOW02        
   DECLARE @c_DiscreteAllocAfterWaveConso NVARCHAR(10),
           @c_DiscreteAllocAfterLoadConso NVARCHAR(10),
           @c_LastLoadkeyOfTheWave        NVARCHAR(10),
           @c_WavekeyOfTheLoad            NVARCHAR(10)         
       
   SELECT @n_StartTCnt = @@TRANCOUNT, @c_ErrMsg = '', @n_Err = 0, @b_Success = 1, @n_Continue = 1
   
   IF @n_continue IN(1,2)
   BEGIN
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         SELECT @c_Storerkey = Storerkey,
                @c_Facility = Facility
         FROM ORDERS (NOLOCK)
         WHERE Orderkey = @c_Orderkey
         
         SET @c_AllocationType = 'DISCRETE'
         
         IF @c_ExtendParms = 'WP'
            SET @c_AllocateFrom = 'WAVE'
         ELSE IF @c_ExtendParms = 'LP'
            SET @c_AllocateFrom = 'LOADPLAN'
         ELSE 
            SET @c_AllocateFrom = 'ORDER'                   
      END
      
      IF ISNULL(@c_Loadkey,'') <> ''
      BEGIN
         SELECT @c_Storerkey = ORDERS.Storerkey,
                @c_Facility = ORDERS.Facility,
                @c_SuperOrderFlag = LOADPLAN.SuperOrderFlag
         FROM LOADPLAN (NOLOCK)
         JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey
         JOIN ORDERS (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey
         WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
               
         SELECT @c_LoadConsoAllocation = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'LoadConsoAllocation')
                   
         IF @c_SuperOrderFlag = 'Y' AND @c_LoadConsoAllocation = '1' 
            SET @c_AllocationType = 'LOADCONSO'
         ELSE 
            SET @c_AllocationType = 'DISCRETE'
         
         IF @c_ExtendParms = 'WP'
            SET @c_AllocateFrom = 'WAVE'
         ELSE
            SET @c_AllocateFrom = 'LOADPLAN'   
      END
      
      IF ISNULL(@c_Wavekey,'') <> ''
      BEGIN
         SELECT @c_Storerkey = ORDERS.Storerkey,
                @c_Facility = ORDERS.Facility
         FROM WAVE (NOLOCK)
         JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.Wavekey
         JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey
         
         SET @c_AllocationType = 'WAVECONSO'
         SET @c_AllocateFrom = 'WAVE'
      END      

      SELECT @c_LoadConsoAllocation = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'LoadConsoAllocation')
      SELECT @c_DiscreteAllocB4LoadConso = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DiscreteAllocB4LoadConso')
      SELECT @c_DiscreteAllocB4WaveConso = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DiscreteAllocB4WaveConso')
      SELECT @c_LoadConsoAllocB4WaveConso = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'LoadConsoAllocB4WaveConso')      	      
      SELECT @c_DiscreteAllocAfterLoadConso = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DiscreteAllocAfterLoadConso') --NJOW02
      SELECT @c_DiscreteAllocAfterWaveConso = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DiscreteAllocAfterWaveConso') --NJOW02
   END
   
   IF @n_continue IN(1,2) AND
       ((@c_DiscreteAllocB4LoadConso = '1' AND @c_AllocationType = 'DISCRETE') OR
        (@c_DiscreteAllocB4WaveConso = '1' AND @c_AllocationType = 'DISCRETE') OR
        (@c_LoadConsoAllocB4WaveConso = '1' AND @c_AllocationType = 'LOADCONSO') OR
        (@c_DiscreteAllocAfterLoadConso = '1' AND @c_AllocationType = 'DISCRETE') OR  --NJOW02
        (@c_DiscreteAllocAfterWaveConso = '1' AND @c_AllocationType = 'DISCRETE')   --NJOW02      
       ) 
   BEGIN
      SELECT @n_continue = 4 --Skip if recurring call
   END    
   
   IF @n_continue IN(1,2) AND @c_Mode = 'PRE'
   BEGIN      		
   		--Execute discrete allocation before continue load conso allocation      
      IF @c_DiscreteAllocB4LoadConso = '1' AND @c_AllocationType = 'LOADCONSO' AND @c_AllocateFrom IN('WAVE','LOADPLAN') 
      BEGIN      	
      	 IF @c_AllocateFrom = 'LOADPLAN'
      	    SET @c_extendparms2 = 'LP'
      	 ELSE 
      	    SET @c_extendparms2 = 'WP'
      	 
         DECLARE CUR_LOADORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT O.Orderkey
            FROM LOADPLANDETAIL LD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
            WHERE LD.Loadkey = @c_Loadkey
            ORDER BY O.Priority, O.Orderkey
            
         OPEN CUR_LOADORD
         
         FETCH NEXT FROM CUR_LOADORD INTO @c_Orderkey2
             
         WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
         BEGIN         	                           	
         	  EXEC nsp_orderprocessing_wrapper 
         	     @c_OrderKey = @c_Orderkey2, 
         	     @c_oskey = '', 
         	     @c_docarton = 'N',
         	     @c_doroute = 'N', 
         	     @c_tblprefix= '', 
         	     @c_Extendparms = @c_extendparms2,
         	     @c_StrategykeyParm = @c_StrategykeyParm --NJOW03
         	
            FETCH NEXT FROM CUR_LOADORD INTO @c_Orderkey2
         END
         CLOSE CUR_LOADORD
         DEALLOCATE CUR_LOADORD             	      	
      END

      --Execute discrete allocation before continue wave conso allocation
      IF @c_DiscreteAllocB4WaveConso = '1' AND @c_AllocationType = 'WAVECONSO' AND @c_AllocateFrom = 'WAVE'
      BEGIN      	
      	 SET @c_extendparms2 = 'WP'
      	 
         DECLARE CUR_WAVORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT O.Orderkey
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
            WHERE WD.Wavekey = @c_Wavekey
            ORDER BY O.Priority, O.Orderkey
            
         OPEN CUR_WAVORD
         
         FETCH NEXT FROM CUR_WAVORD INTO @c_Orderkey2
             
         WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
         BEGIN
         	  EXEC nsp_orderprocessing_wrapper 
         	     @c_OrderKey = @c_Orderkey2, 
         	     @c_oskey = '', 
         	     @c_docarton = 'N',
         	     @c_doroute = 'N', 
         	     @c_tblprefix= '', 
         	     @c_Extendparms = @c_extendparms2,
         	     @c_StrategykeyParm = @c_StrategykeyParm --NJOW03
         	              	
            FETCH NEXT FROM CUR_WAVORD INTO @c_Orderkey2
         END
         CLOSE CUR_WAVORD
         DEALLOCATE CUR_WAVORD             	      	
      END               
      
      --Execute load conso allocation before continue wave conso allocation      
      IF @c_LoadConsoAllocB4WaveConso = '1' AND @c_AllocationType = 'WAVECONSO' AND @c_AllocateFrom = 'WAVE' AND @c_LoadConsoAllocation = '1'
      BEGIN      	
      	 SET @c_extendparms2 = 'WP'
      	 
         DECLARE CUR_WAVLOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT O.Loadkey
            FROM WAVEDETAIL WD (NOLOCK)            
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
            JOIN LOADPLAN L (NOLOCK) ON O.Loadkey = L.Loadkey
            WHERE WD.Wavekey = @c_Wavekey
            AND L.SuperOrderFlag = 'Y'
            ORDER BY O.Loadkey
            
         OPEN CUR_WAVLOAD
         
         FETCH NEXT FROM CUR_WAVLOAD INTO @c_Loadkey2
             
         WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
         BEGIN
         	  EXEC nsp_orderprocessing_wrapper 
         	     @c_OrderKey = '', 
         	     @c_oskey = @c_Loadkey2, 
         	     @c_docarton = 'N',
         	     @c_doroute = 'N', 
         	     @c_tblprefix= '', 
         	     @c_Extendparms = @c_extendparms2,
         	     @c_StrategykeyParm = @c_StrategykeyParm --NJOW03
         	              	
            FETCH NEXT FROM CUR_WAVLOAD INTO @c_Loadkey2
         END
         CLOSE CUR_WAVLOAD
         DEALLOCATE CUR_WAVLOAD             	      	
      END                           
   END 
   
   IF @n_continue IN(1,2) AND @c_Mode = 'POST' 
   BEGIN
   		--Execute discrete allocation after continue load conso allocation --NJOW02     
      IF @c_DiscreteAllocAfterLoadConso = '1' AND @c_AllocationType = 'LOADCONSO' AND @c_AllocateFrom IN('WAVE','LOADPLAN') 
      BEGIN      	
      	 IF @c_AllocateFrom = 'LOADPLAN'
      	    SET @c_extendparms2 = 'LP'
      	 ELSE 
      	    SET @c_extendparms2 = 'WP'
      	 
      	 IF @c_AllocateFrom = 'WAVE' --if load conso is called from wave, only execute discrete allocate of the wave at the last load.
      	 BEGIN
      	 	 --get wavekey of the loadplan
      	 	 SELECT TOP 1 @c_WavekeyOfTheLoad = WD.Wavekey
      	 	 FROM LOADPLANDETAIL LPD (NOLOCK)
      	 	 JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
      	 	 JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Wavekey
      	 	 WHERE LPD.Loadkey = @c_Loadkey 
      	 	 ORDER BY WD.Wavekey
      	 	 
      	 	 --get last loadkey of the wave
      	 	 SELECT TOP 1 @c_LastLoadkeyOfTheWave = LPD.Loadkey
      	 	 FROM WAVEDETAIL WD (NOLOCK)
      	 	 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey      	 	 
      	 	 JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
      	 	 WHERE WD.Wavekey = @c_WavekeyOfTheLoad 
      	 	 ORDER BY LPD.Loadkey DESC
      	 	 
      	 	 IF @c_LastLoadkeyOfTheWave = @c_Loadkey  --Last loadkey of the wave
      	 	 BEGIN
              DECLARE CUR_WAVEORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                 SELECT O.Orderkey
                 FROM WAVEDETAIL WD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                 WHERE WD.Wavekey = @c_WavekeyOfTheLoad
                 AND O.Status < '2'
                 ORDER BY O.Priority, O.Orderkey
                 
              OPEN CUR_WAVEORD
              
              FETCH NEXT FROM CUR_WAVEORD INTO @c_Orderkey2
                  
              WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
              BEGIN
              	  EXEC nsp_orderprocessing_wrapper 
              	     @c_OrderKey = @c_Orderkey2, 
              	     @c_oskey = '', 
              	     @c_docarton = 'N',
              	     @c_doroute = 'N', 
              	     @c_tblprefix= '', 
              	     @c_Extendparms = @c_extendparms2,
              	     @c_StrategykeyParm = @c_StrategykeyParm --NJOW03              	     
              	
                 FETCH NEXT FROM CUR_WAVEORD INTO @c_Orderkey2
              END
              CLOSE CUR_WAVEORD
              DEALLOCATE CUR_WAVEORD      	 	 	  
      	 	 END
      	 END
      	 ELSE
      	 BEGIN      	    
            DECLARE CUR_LOADORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT O.Orderkey
               FROM LOADPLANDETAIL LD (NOLOCK)
               JOIN ORDERS O (NOLOCK) ON LD.Orderkey = O.Orderkey
               WHERE LD.Loadkey = @c_Loadkey
               AND O.Status < '2'
               ORDER BY O.Priority, O.Orderkey
               
            OPEN CUR_LOADORD
            
            FETCH NEXT FROM CUR_LOADORD INTO @c_Orderkey2
                
            WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
            BEGIN
            	  EXEC nsp_orderprocessing_wrapper 
            	     @c_OrderKey = @c_Orderkey2, 
            	     @c_oskey = '', 
            	     @c_docarton = 'N',
            	     @c_doroute = 'N', 
            	     @c_tblprefix= '', 
            	     @c_Extendparms = @c_extendparms2,
            	     @c_StrategykeyParm = @c_StrategykeyParm --NJOW03            	     
            	
               FETCH NEXT FROM CUR_LOADORD INTO @c_Orderkey2
            END
            CLOSE CUR_LOADORD
            DEALLOCATE CUR_LOADORD
         END             	      	
      END

      --Execute discrete allocation after continue wave conso allocation --NJOW02
      IF @c_DiscreteAllocAfterWaveConso = '1' AND @c_AllocationType = 'WAVECONSO' AND @c_AllocateFrom = 'WAVE'
      BEGIN      	
      	 SET @c_extendparms2 = 'WP'
      	 
         DECLARE CUR_WAVORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT O.Orderkey
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
            WHERE WD.Wavekey = @c_Wavekey
            ORDER BY O.Priority, O.Orderkey
            
         OPEN CUR_WAVORD
         
         FETCH NEXT FROM CUR_WAVORD INTO @c_Orderkey2
             
         WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
         BEGIN
         	  EXEC nsp_orderprocessing_wrapper 
         	     @c_OrderKey = @c_Orderkey2, 
         	     @c_oskey = '', 
         	     @c_docarton = 'N',
         	     @c_doroute = 'N', 
         	     @c_tblprefix= '', 
         	     @c_Extendparms = @c_extendparms2,
         	     @c_StrategykeyParm = @c_StrategykeyParm --NJOW03
         	              	
            FETCH NEXT FROM CUR_WAVORD INTO @c_Orderkey2
         END
         CLOSE CUR_WAVORD
         DEALLOCATE CUR_WAVORD             	      	
      END                  	
   	
      SELECT @b_success = 0
   
      Execute nspGetRight 
         @c_Facility  = @c_facility,  
         @c_StorerKey = @c_StorerKey,              
         @c_sku       = '',                    
         @c_ConfigKey = 'PostAllocIdentifyConsoUnit', 
         @b_Success   = @b_success                    OUTPUT,
         @c_authority = @c_PostAllocIdentifyConsoUnit OUTPUT,
         @n_err       = @n_err                        OUTPUT,
         @c_errmsg    = @c_errmsg                     OUTPUT,
         @c_Option1   = @c_option1                    OUTPUT,
         @c_Option2   = @c_option2                    OUTPUT,
         @c_Option3   = @c_option3                    OUTPUT,
         @c_Option4   = @c_option4                    OUTPUT,
         @c_Option5   = @c_option5                    OUTPUT
      
      --Indentity pickdetail of consolidate full carton or pallet and update to indicate
      --optional to consolidate loose to become consolidate full carton or pallet
      IF @b_Success = '1' AND @c_PostAllocIdentifyConsoUnit = '1' 
      BEGIN
      	 SET @c_UOM = '2'                     
         SET @c_GroupFieldList = ''           
         SET @c_ConsoGroupFieldList = ''      
         SET @c_SQLCondition = ''             
         SET @c_CaseCntByUCC = 'N'             
         SET @c_PickMethodOfConso = ''       
         SET @c_UOMOfConso = ''               
         SET @c_ConsolidatePieceProcess = 'N'  
         SET @c_IdentifyConsoUnitProcess  ='Y'
         SET @c_ConsoUnitByUCCNo = 'N' --NJOW04
         
         IF (@c_AllocateFrom = 'LOADPLAN' AND @c_AllocationType = 'DISCRETE') OR (@c_AllocateFrom = 'WAVE' AND @c_AllocationType = 'DISCRETE')
             SET @c_ConsolidatePieceProcess = 'Y'  
   
         IF ISNULL(@c_Option5,'') <> ''
         BEGIN
         	  SELECT @c_UOM = dbo.fnc_GetParamValueFromString('@c_UOM', @c_Option5, @c_UOM) --can set the value as 1,2 for both pallet and carton
         	  SELECT @c_GroupFieldList = dbo.fnc_GetParamValueFromString('@c_GroupFieldList', @c_Option5, @c_GroupFieldList)
         	  SELECT @c_ConsoGroupFieldList = dbo.fnc_GetParamValueFromString('@c_ConsoGroupFieldList', @c_Option5, @c_ConsoGroupFieldList)
         	  SELECT @c_SQLCondition = dbo.fnc_GetParamValueFromString('@c_SQLCondition', @c_Option5, @c_SQLCondition)
         	  SELECT @c_CaseCntByUCC = dbo.fnc_GetParamValueFromString('@c_CaseCntByUCC', @c_Option5, @c_CaseCntByUCC)
         	  SELECT @c_PickMethodOfConso = dbo.fnc_GetParamValueFromString('@c_PickMethodOfConso', @c_Option5, @c_PickMethodOfConso)
         	  SELECT @c_UOMOfConso = dbo.fnc_GetParamValueFromString('@c_UOMOfConso', @c_Option5, @c_UOMOfConso) --can set the value as 1,2 for both pallet and carton
         	  SELECT @c_ConsolidatePieceProcess = dbo.fnc_GetParamValueFromString('@c_ConsolidatePieceProcess', @c_Option5, @c_ConsolidatePieceProcess)
         	  SELECT @c_IdentifyConsoUnitProcess = dbo.fnc_GetParamValueFromString('@c_IdentifyConsoUnitProcess', @c_Option5, @c_IdentifyConsoUnitProcess)
         	  SELECT @c_ConsoUnitByUCCNo = dbo.fnc_GetParamValueFromString('@c_ConsoUnitByUCCNo', @c_Option5, @c_ConsoUnitByUCCNo)  --NJOW04
         END                  
          
         SET @n_SeqNo = 0 
         SELECT @n_SeqNo = Seqno FROM dbo.fnc_DelimSplit(',',@c_UOM) WHERE Colvalue = '1'
                   
      	 IF @n_SeqNo > 0
      	 BEGIN   	
      	 	  SET @c_TempUOMofConso = ''
      	 	  SELECT @c_TempUOMofConso = ColValue FROM dbo.fnc_DelimSplit(',',@c_UOMOfConso) WHERE Seqno = @n_SeqNo
      	 	  
      	 	  IF ISNULL(@c_TempUOMofConso,'') = ''
      	 	     SET @c_TempUOMofConso = @c_UOMOfConso      	 	        	 	 
      	 	  
            EXEC isp_ConsolidatePickdetail   	
                @c_Loadkey = @c_Loadkey                    
               ,@c_Wavekey = @c_Wavekey        
               ,@c_UOM = '1'                         
               ,@c_GroupFieldList = @c_GroupFieldList              
               ,@c_ConsoGroupFieldList = @c_ConsoGroupFieldList         
               ,@c_SQLCondition = @c_SQLCondition                
               ,@c_CaseCntByUCC = @c_CaseCntByUCC                
               ,@c_PickMethodOfConso = @c_PickMethodOfConso            
               ,@c_UOMOfConso = @c_TempUOMofConso                  
               ,@c_ConsolidatePieceProcess = @c_ConsolidatePieceProcess     
               ,@c_IdentifyConsoUnitProcess = @c_IdentifyConsoUnitProcess        
               ,@c_ConsoUnitByUCCNo = @c_ConsoUnitByUCCNo  --NJOW04                                     
               ,@b_Success = @b_Success OUTPUT                   
               ,@n_Err = @n_Err OUTPUT        
               ,@c_ErrMsg = @c_ErrMsg OUTPUT         
               
            IF @b_Success <> 1
               SET @n_Continue = 3   
         END         
      	
         SET @n_SeqNo = 0 
         SELECT @n_SeqNo = Seqno FROM dbo.fnc_DelimSplit(',',@c_UOM) WHERE Colvalue = '2'
                   
      	 IF @n_SeqNo > 0
      	 BEGIN   	
      	 	  SET @c_TempUOMofConso = ''
      	 	  SELECT @c_TempUOMofConso = ColValue FROM dbo.fnc_DelimSplit(',',@c_UOMOfConso) WHERE Seqno = @n_SeqNo
      	 	  
      	 	  IF ISNULL(@c_TempUOMofConso,'') = ''
      	 	     SET @c_TempUOMofConso = @c_UOMOfConso      	 	        	 	 

            EXEC isp_ConsolidatePickdetail   	
                @c_Loadkey = @c_Loadkey                    
               ,@c_Wavekey = @c_Wavekey        
               ,@c_UOM = '2'                         
               ,@c_GroupFieldList = @c_GroupFieldList              
               ,@c_ConsoGroupFieldList = @c_ConsoGroupFieldList         
               ,@c_SQLCondition = @c_SQLCondition                
               ,@c_CaseCntByUCC = @c_CaseCntByUCC                
               ,@c_PickMethodOfConso = @c_PickMethodOfConso            
               ,@c_UOMOfConso = @c_TempUOMofConso                  
               ,@c_ConsolidatePieceProcess = @c_ConsolidatePieceProcess     
               ,@c_IdentifyConsoUnitProcess = @c_IdentifyConsoUnitProcess              
               ,@c_ConsoUnitByUCCNo = @c_ConsoUnitByUCCNo  --NJOW04                                                                                   
               ,@b_Success = @b_Success OUTPUT                   
               ,@n_Err = @n_Err OUTPUT        
               ,@c_ErrMsg = @c_ErrMsg OUTPUT         

            IF @b_Success <> 1
               SET @n_Continue = 3               
         END         
      END   	
   END

   RETURN_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_PrePostallocate_Process'  
  		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END

GO