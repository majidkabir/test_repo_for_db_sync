SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/            
/* Stored Proc: isp_wavetask_summary_rpt                                   */            
/* Creation Date: 04-JUNE-2019                                             */            
/* Copyright: LF Logistics                                                 */            
/* Written by: CSCHONG                                                     */            
/*                                                                         */            
/* Purpose:WMS-9202-[CN] Logitech Hyperion task report                     */            
/*        :                                                                */            
/* Called By: r_wavetask_summary_rpt                                       */            
/*          :                                                              */            
/* PVCS Version: 1.0                                                       */            
/*                                                                         */            
/* Data Modifications:                                                     */            
/*                                                                         */            
/* Updates:                                                                */            
/* Date         Author     Ver  Purposes                                   */              
/***************************************************************************/            
CREATE PROC [dbo].[isp_wavetask_summary_rpt]            
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
         , @n_ctnflk            decimal(5,2)           
         , @n_ctnextordkey      INT
         , @n_cntAll            decimal(5,2)          
         , @n_FLKP             decimal(5,2)           
            
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
   SET @n_ctnflk       = 1.00
   SET @n_cntAll       = 1.00
            
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


   SELECT @n_ctnextordkey = COUNT(DISTINCT ORD.Externorderkey)
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

   SET @n_FLKP = ((@n_ctnflk*100)/@n_cntAll)
            
     CREATE TABLE #TMP_TSUMMRPT           
      (  RowID              INT IDENTITY (1,1) NOT NULL             
      ,  wavekey            NVARCHAR(20)   NULL  DEFAULT('')            
      ,  TaskQty            INT            NULL              
      ,  Casecnt            FLOAT          NULL                
      ,  PutawayZone        NVARCHAR(45)   NULL  DEFAULT('')   
      ,  Consigneekey       NVARCHAR(45)   NULL  DEFAULT('') 
      ,  CRemarks           NVARCHAR(100)  NULL  DEFAULT('') 
      ,  Pltmethod          NVARCHAR(100)  NULL  DEFAULT('')     
      ,  Country            NVARCHAR(45)   NULL  DEFAULT('') 
      ,  logicalToloc       NVARCHAR(10)   NULL  DEFAULT('')  
      ,  CAddress4          NVARCHAR(45)   NULL  DEFAULT('') 
      ,  CTNExtOrdkey       INT            NULL
      ,  ShipMethod         NVARCHAR(100)  NULL  DEFAULT('') 
      ,  FPKPercentage      DECIMAL(5,2)   NULL
      ,  TaskType           NVARCHAR(10)   NULL  DEFAULT('') 
      ,  Lottable05         NVARCHAR(10)   NULL  DEFAULT('') 
      ,  FromLOC            NVARCHAR(10)   NULL  DEFAULT('') 
      ,  SKU                NVARCHAR(20)   NULL  DEFAULT('')  
      ,  SOVAS              NVARCHAR(30)   NULL  DEFAULT('') 
      ,  Lottable08         NVARCHAR(30)   NULL  DEFAULT('') 
      )            
            
     INSERT INTO #TMP_TSUMMRPT (wavekey             
                             ,  TaskQty             
                             ,  Casecnt             
                             ,  PutawayZone         
                             ,  Consigneekey        
                             ,  CRemarks            
                             ,  Pltmethod           
                             ,  Country             
                             ,  logicalToloc        
                             ,  CAddress4           
                             ,  CTNExtOrdkey        
                             ,  ShipMethod          
                             ,  FPKPercentage        
                             ,  TaskType            
                             ,  Lottable05          
                             ,  FromLOC             
                             ,  SKU                 
                             ,  SOVAS               
                             ,  Lottable08          
                            )                                             
         SELECT TD.Wavekey,SUM(TD.Qty),P.casecnt,L.Putawayzone,@c_consigneekey,@c_cremarks,@c_pltmethod ,@c_country
                ,TD.logicaltoloc,@c_CAddress4, @n_ctnextordkey , @c_shipmethod,@n_FLKP,TD.tasktype ,LOTT.lottable05,TD.Fromloc
                ,TD.sku,S.ovas,LOTT.lottable08     
         FROM TaskDetail TD WITH (NOLOCK)           
         JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc 
         JOIN SKU S WITH (NOLOCK) ON S.Storerkey = TD.Storerkey and S.SKU = TD.SKU 
         JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey  
         JOIN LOTATTRIBUTE LOTT WITH (Nolock) ON LOTT.Lot=TD.Lot AND TD.Sku=LOTT.Sku AND LOTT.StorerKey=TD.Storerkey 
         WHERE TD.StorerKey = @c_storerkey             
         AND TD.Wavekey = @c_waveKey   
         AND L.Facility =   @c_Facility  
         GROUP BY TD.Wavekey,P.casecnt,L.Putawayzone,TD.logicaltoloc,TD.tasktype ,LOTT.lottable05,TD.Fromloc
                 ,TD.sku,S.ovas,LOTT.lottable08        
         ORDER BY TD.Wavekey,L.Putawayzone           
            
   SELECT wavekey             
        ,  TaskQty             
        ,  Casecnt             
        ,  PutawayZone         
        ,  Consigneekey        
        ,  CRemarks            
        ,  Pltmethod           
        ,  Country             
        ,  logicalToloc        
        ,  CAddress4           
        ,  CTNExtOrdkey        
        ,  ShipMethod          
        ,  FPKPercentage        
        ,  TaskType            
        ,  Lottable05          
        ,  FromLOC             
        ,  SKU                 
        ,  SOVAS               
        ,  Lottable08      
   FROM #TMP_TSUMMRPT             
   ORDER BY Wavekey,putawayzone              
            
   WHILE @@TRANCOUNT < @n_StartTCnt            
   BEGIN            
      BEGIN TRAN            
   END            
END -- procedure 

GO