SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/            
/* Stored Proc: isp_wavetask_barcode_rpt                                   */            
/* Creation Date: 04-JUNE-2019                                             */            
/* Copyright: LF Logistics                                                 */            
/* Written by: CSCHONG                                                     */            
/*                                                                         */            
/* Purpose:WMS-9282-CN Logitech Hyperion task report - bar code            */            
/*        :                                                                */            
/* Called By: r_wavetask_barcode_rpt                                       */            
/*          :                                                              */            
/* PVCS Version: 1.0                                                       */            
/*                                                                         */            
/* Data Modifications:                                                     */            
/*                                                                         */            
/* Updates:                                                                */            
/* Date         Author     Ver  Purposes                                   */              
/***************************************************************************/            
CREATE PROC [dbo].[isp_wavetask_barcode_rpt]            
           @c_waveKey         NVARCHAR(150),
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
         , @c_arcdbname         NVARCHAR(50)            
         , @c_lot               NVARCHAR(50)            
         , @n_Pcs               INT            
         , @n_OriSalesPrice     FLOAT            
         , @n_ARHOriSalesPrice  FLOAT            
         , @c_reasoncode        NVARCHAR(45)            
         , @c_codedescr         NVARCHAR(120)            
         , @c_lottable02        NVARCHAR(20)            
         , @c_polott02          NVARCHAR(20)            
         , @c_Sql               NVARCHAR(MAX)            
         , @c_SqlParms          NVARCHAR(4000)            
         , @c_DataMartServerDB  NVARCHAR(120)            
         , @sql                 NVARCHAR(MAX)            
         , @sqlinsert           NVARCHAR(MAX)            
         , @sqlselect           NVARCHAR(MAX)            
         , @sqlfrom             NVARCHAR(MAX)            
         , @sqlwhere            NVARCHAR(MAX)        
         , @c_SQLSelect         NVARCHAR(4000)            
         , @n_Uprice            FLOAT            
         , @n_GTPcs             INT            
         , @n_GTPLOT            FLOAT            
            
   SET @n_StartTCnt = @@TRANCOUNT            
               
   SET @n_NoOfLine = 12            
            
   WHILE @@TRANCOUNT > 0            
   BEGIN            
      COMMIT TRAN            
   END            
                     
    IF ISNULL(@c_storerkey,'') = ''
   BEGIN
     SELECT TOP 1 @c_storerkey = TD.Storerkey
     FROM TASKDETAIL TD WITH (NOLOCK)
     WHERE TD.Wavekey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_waveKey)) 
   END

   IF ISNULL(@c_Facility,'') = ''
   BEGIN
     SELECT TOP 1 @c_Facility = L.Facility
     FROM TaskDetail TD WITH (NOLOCK)
     JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc 
     WHERE TD.Wavekey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_waveKey)) 
   END
            
     CREATE TABLE #TMP_TRPTBAR            
      (  RowID              INT IDENTITY (1,1) NOT NULL             
      ,  wavekey            NVARCHAR(150)   NULL  DEFAULT('')            
      ,  TaskQty            INT            NULL              
      ,  Casecnt            FLOAT          NULL                
      ,  PutawayZone        NVARCHAR(45)   NULL  DEFAULT('')
     ,  WPBarcode          NVARCHAR(50)   NULL  DEFAULT('')          
      )            
            
         INSERT INTO #TMP_TRPTBAR (Wavekey,Taskqty,casecnt,putawayzone,WPBarcode)
         SELECT MIN(TD.Wavekey),SUM(TD.Qty),MIN(P.casecnt),L.Putawayzone,(MIN(TD.Wavekey)+L.Putawayzone)       
         FROM TaskDetail TD WITH (NOLOCK)           
         JOIN LOC L WITH (NOLOCK) ON L.Loc = TD.FromLoc 
         JOIN SKU S WITH (NOLOCK) ON S.Storerkey = TD.Storerkey and S.SKU = TD.SKU 
         JOIN PACK P WITH (NOLOCK) ON P.Packkey = S.Packkey   
         WHERE TD.StorerKey = @c_storerkey             
         AND TD.Wavekey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_waveKey))       
         AND L.Facility =   @c_Facility  
         group by L.Putawayzone        
         Order By L.Putawayzone           
            
   --SELECT Wavekey,Taskqty,casecnt,putawayzone,WPBarcode        
   --FROM #TMP_TRPTBAR             
   --Order by Wavekey,putawayzone    
   
    SELECT @c_waveKey,Taskqty,casecnt,putawayzone,WPBarcode        
    FROM #TMP_TRPTBAR             
    Order by putawayzone            
            
   WHILE @@TRANCOUNT < @n_StartTCnt            
   BEGIN            
      BEGIN TRAN            
   END            
END -- procedure 

GO