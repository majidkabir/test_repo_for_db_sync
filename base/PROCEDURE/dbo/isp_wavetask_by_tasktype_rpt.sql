SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/            
/* Stored Proc: isp_wavetask_by_tasktype_rpt                               */            
/* Creation Date: 14-JUNE-2019                                             */            
/* Copyright: LF Logistics                                                 */            
/* Written by: CSCHONG                                                     */            
/*                                                                         */            
/* Purpose:WMS-9266-[CN] Logitech Hyperion sub-task repor                  */            
/*        :                                                                */            
/* Called By: r_wavetask_by_tasktype_rpt                                   */            
/*          :                                                              */            
/* PVCS Version: 1.0                                                       */            
/*                                                                         */            
/* Data Modifications:                                                     */            
/*                                                                         */            
/* Updates:                                                                */            
/* Date         Author     Ver  Purposes                                   */              
/***************************************************************************/            
CREATE PROC [dbo].[isp_wavetask_by_tasktype_rpt]            
           @c_waveKey         NVARCHAR(10),
		   @c_storerKey       NVARCHAR(10) = '',            
           @c_facility        NVARCHAR(10) = '',             
           @c_tasktype        NVARCHAR(20) = ''            
            
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF               
            
   DECLARE              
           @n_StartTCnt         INT            
         , @n_Continue          INT            
         , @n_NoOfLine          INT                       
         , @c_lot               NVARCHAR(50)                       
         , @c_reasoncode        NVARCHAR(45)            
         , @c_cremarks          NVARCHAR(120)   
		 , @c_pltmethod         NVARCHAR(120)
		 , @c_shipmethod        NVARCHAR(120)         
         , @c_lottable05        NVARCHAR(20)            
         , @c_lottable08        NVARCHAR(30) 
		 , @c_consigneekey      NVARCHAR(45) 
		 , @c_country           NVARCHAR(45) 
		 , @c_ordcompany        NVARCHAR(45)
         , @c_CAddress4         NVARCHAR(45)
		 , @c_OrdUDF03          NVARCHAR(45)
         , @c_Sql               NVARCHAR(MAX)            
         , @c_SqlParms          NVARCHAR(4000)                      
         , @sql                 NVARCHAR(MAX)            
         , @sqlinsert           NVARCHAR(MAX)            
         , @sqlselect           NVARCHAR(MAX)            
         , @sqlfrom             NVARCHAR(MAX)            
         , @sqlwhere            NVARCHAR(MAX)        
         , @c_SQLSelect         NVARCHAR(4000)            
         , @n_ctnflk            INT            
         , @n_ctnextordkey      INT
		 , @n_cntAll            INT            
         , @n_FLKP              FLOAT  
		 , @c_picklbl           NVARCHAR(120)   
		 , @c_rpllbl            NVARCHAR(120)        
            
   SET @n_StartTCnt = @@TRANCOUNT            
               
   SET @n_NoOfLine     = 12       
   SET @c_cremarks     = '' 
   SET @c_pltmethod    = ''
   SET @c_shipmethod   = ''       
   SET @c_lottable05   = ''
   SET @c_lottable08   =''
   SET @c_consigneekey = ''
   SET @c_country      = ''
   SET @c_ordcompany   = ''
   SET @c_CAddress4    = ''
   SET @c_OrdUDF03     = '' 
   SET @n_FLKP         = 0
   SET @n_ctnextordkey = 1
   SET @n_ctnflk       = 1
   SET @n_cntAll       = 1
            
   WHILE @@TRANCOUNT > 0            
   BEGIN            
      COMMIT TRAN            
   END            
                     
    IF ISNULL(@c_storerkey,'') = ''
	BEGIN
	  SELECT TOP 1 @c_storerkey = ORD.Storerkey
	  FROM ORDERS ORD WITH (NOLOCK)
	  WHERE ORD.userdefine09 = @c_waveKey
	END

	IF ISNULL(@c_Facility,'') = ''
	BEGIN
	  SELECT TOP 1 @c_Facility = ORD.Facility
	   FROM ORDERS ORD WITH (NOLOCK)
	  WHERE ORD.userdefine09 = @c_waveKey
	END


	SELECT @c_consigneekey = ORD.consigneekey
	      ,@c_country      = ORD.c_country
		  ,@c_CAddress4    = ORD.C_Address4
		  ,@c_OrdUDF03     = ORD.Userdefine03
		  ,@c_ordcompany   = SUBSTRING(ORD.c_company,1,6) 
	FROM ORDERS ORD WITH (NOLOCK)
	WHERE ORD.userdefine09 = @c_waveKey


	select @n_ctnextordkey = COUNT(DISTINCT ORD.Externorderkey)
	FROM ORDERS ORD WITH (NOLOCK)
	WHERE ORD.userdefine09 = @c_waveKey

	SELECT @c_cremarks = C.long
	FROM Codelkup C WITH (NOLOCK) 
	WHERE C.listname='CONSINEELBL'
	AND ( C.code = @c_consigneekey OR C.short = @c_consigneekey)
  
   IF ISNULL(@c_cremarks,'') = ''
   BEGIN
    SET @c_cremarks = '1'
   END

   SELECT @c_shipmethod = C.long
	FROM Codelkup C WITH (NOLOCK) 
	WHERE C.listname='ShipMethod'
	AND C.short = @c_OrdUDF03
  
   IF ISNULL(@c_shipmethod,'') = ''
   BEGIN
    SET @c_shipmethod = @c_OrdUDF03
   END

   SELECT @c_pltmethod = C.notes
	FROM Codelkup C WITH (NOLOCK) 
	WHERE C.listname='PalletMethod'
	AND C.code = @c_ordcompany
	AND C.short = @c_OrdUDF03
	and C.long <>@c_CAddress4
  
   IF ISNULL(@c_pltmethod,'') = ''
   BEGIN
    SET @c_pltmethod = '1'
   END

   SELECT @n_ctnflk = COUNT(1)
   FROM TaskDetail TD WITH (NOLOCK)  
   JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc
   WHERE TD.StorerKey = @c_storerkey             
   AND TD.Wavekey = @c_waveKey   
   AND L.Facility =   @c_Facility  
   AND TD.TaskType = 'FPK'

   SELECT @n_cntAll = COUNT(1)
   FROM TaskDetail TD WITH (NOLOCK) 
   JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc
   WHERE TD.StorerKey = @c_storerkey             
   AND TD.Wavekey = @c_waveKey   
   AND L.Facility =   @c_Facility  

   IF ISNULL(@c_tasktype,'') = ''
   BEGIN
      SELECT TOP 1 @c_tasktype = TD.TaskType
	              ,@c_lottable05 = convert(nvarchar(10),LOTT.Lottable05,121)
				  ,@c_lottable08 = LOTT.lottable08
	  FROM TaskDetail TD WITH (NOLOCK)
	  JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc
	  JOIN LOTATTRIBUTE LOTT WITH (Nolock) ON LOTT.Lot=TD.Lot AND TD.Sku=LOTT.Sku AND LOTT.StorerKey=TD.Storerkey
      WHERE TD.StorerKey = @c_storerkey             
      AND TD.Wavekey = @c_waveKey   
      AND L.Facility =   @c_Facility  
   END

   SELECT @c_picklbl = C.notes
   FROM TaskDetail TD WITH (NOLOCK) 
   JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'PickLBL'
                                      AND C.short = L.PutawayZone
									  AND C.code <> @c_tasktype
									  AND C.long = @c_lottable08
   WHERE TD.StorerKey = @c_storerkey             
   AND TD.Wavekey = @c_waveKey   
   AND L.Facility =   @c_Facility 


   if ISNULL(@c_picklbl,'') = ''
   BEGIN
     SET @c_picklbl =N'不要拣黄/绿标货物'
   END

   SELECT @c_rpllbl = C.long
   FROM TaskDetail TD WITH (NOLOCK) 
   JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'PickLBL'
                                      AND C.short = @c_lottable08
									  AND C.code <> @c_tasktype
   WHERE TD.StorerKey = @c_storerkey             
   AND TD.Wavekey = @c_waveKey   
   AND L.Facility =   @c_Facility 


   if ISNULL(@c_rpllbl,'') = ''
   BEGIN
     SET @c_rpllbl =N'不要拣黄/绿标货物'
   END


   SET @n_FLKP = @n_ctnflk/nullif(@n_cntAll,0)
            
     CREATE TABLE #TMP_TASKTYPRPT           
      (  RowID              INT IDENTITY (1,1) NOT NULL             
      ,  wavekey            NVARCHAR(20)   NULL  DEFAULT('')            
      ,  TaskQty            INT            NULL           
      ,  Casecnt            FLOAT          NULL                
     -- ,  PutawayZone        NVARCHAR(45)   NULL  DEFAULT('')   
	  ,  Consigneekey       NVARCHAR(45)   NULL  DEFAULT('') 
	  ,  CRemarks           NVARCHAR(100)  NULL  DEFAULT('') 
	  ,  Pltmethod          NVARCHAR(100)  NULL  DEFAULT('')     
	  ,  Country            NVARCHAR(45)   NULL  DEFAULT('') 
	  ,  logicalToloc       NVARCHAR(10)   NULL  DEFAULT('')  
	  ,  CAddress4          NVARCHAR(45)   NULL  DEFAULT('') 
	  ,  CTNExtOrdkey       INT            NULL
	  ,  ShipMethod         NVARCHAR(100)  NULL  DEFAULT('') 
	  ,  PickLBL            NVARCHAR(100)  NULL  DEFAULT('')
	  ,  TaskType           NVARCHAR(10)   NULL  DEFAULT('') 
	  ,  Lottable05         NVARCHAR(10)   NULL  DEFAULT('') 
	  ,  FromLOC            NVARCHAR(10)   NULL  DEFAULT('') 
	  ,  SKU                NVARCHAR(20)   NULL  DEFAULT('')  
	  ,  SOVAS              NVARCHAR(30)   NULL  DEFAULT('') 
	  ,  Lottable08         NVARCHAR(30)   NULL  DEFAULT('')
	  ,  RPLLBL             NVARCHAR(100)  NULL  DEFAULT('')  
      )            
            
     INSERT INTO #TMP_TASKTYPRPT (wavekey             
                             ,  TaskQty             
                             ,  Casecnt             
                           --  ,  PutawayZone         
                             ,  Consigneekey        
                             ,  CRemarks            
                             ,  Pltmethod           
                             ,  Country             
                             ,  logicalToloc        
                             ,  CAddress4           
                             ,  CTNExtOrdkey        
                             ,  ShipMethod          
                             ,  PickLBL        
                             ,  TaskType            
                             ,  Lottable05          
                             ,  FromLOC             
                             ,  SKU                 
                             ,  SOVAS               
                             ,  Lottable08 
							 ,  RPLLBL         
                            )                                             
		    SELECT TD.Wavekey,SUM(TD.Qty),P.casecnt,--L.Putawayzone,
			@c_consigneekey,@c_cremarks,@c_pltmethod ,@c_country
			      ,TD.logicaltoloc,@c_CAddress4, @n_ctnextordkey , @c_shipmethod,@c_picklbl,TD.tasktype ,@c_lottable05,TD.Fromloc
				  ,TD.sku,S.ovas,@c_lottable08,@c_rpllbl     
            FROM TaskDetail TD WITH (NOLOCK)           
			JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc 
			JOIN SKU S WITH (NOLOCK) ON S.Storerkey = TD.Storerkey and S.SKU = TD.SKU 
			JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey  
			--JOIN LOTATTRIBUTE LOTT WITH (Nolock) ON LOTT.Lot=TD.Lot AND TD.Sku=LOTT.Sku AND LOTT.StorerKey=TD.Storerkey 
            WHERE TD.StorerKey = @c_storerkey             
            AND TD.Wavekey = @c_waveKey   
			AND L.Facility =   @c_Facility  
			group by TD.Wavekey,P.casecnt,--L.Putawayzone,
			TD.logicaltoloc,TD.tasktype ,TD.Fromloc
				  ,TD.sku,S.ovas   
            Order By TD.Wavekey--,L.Putawayzone           
            
   SELECT wavekey             
        ,  TaskQty             
        ,  Casecnt             
       -- ,  PutawayZone         
        ,  Consigneekey        
        ,  CRemarks            
        ,  Pltmethod           
        ,  Country             
        ,  logicalToloc        
        ,  CAddress4           
        ,  CTNExtOrdkey        
        ,  ShipMethod          
        ,  PickLBL        
        ,  TaskType            
        ,  Lottable05          
        ,  FromLOC             
        ,  SKU                 
        ,  SOVAS               
        ,  Lottable08  
		,RPLLBL    
   FROM #TMP_TASKTYPRPT             
   Order by Wavekey--,putawayzone              
            
   WHILE @@TRANCOUNT < @n_StartTCnt            
   BEGIN            
      BEGIN TRAN            
   END            
END -- procedure 

GO