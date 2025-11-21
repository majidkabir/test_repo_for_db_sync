SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_Dashboard_GetAutoAllocStatus                   */    
/* Creation Date:                                                       */    
/* Copyright: LFL                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.3 (Unicode)                                          */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Rev   Purposes                                  */  
/* 11Nov2018    TLTING  1.1   Performanace tune                         */  
/************************************************************************/      
CREATE PROC [dbo].[isp_Dashboard_GetAutoAllocStatus]   
AS   
BEGIN  
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF 
	
   DECLARE   
      @n_TotalQTask   INT = 0,  
      @n_QTaskWIP     INT = 0,  
      @n_QTaskError   INT = 0,   
      @n_Allocated    INT = 0,  
      @n_Batched      INT = 0,
      @n_NotSubmit    INT = 0,
      @n_NoStock      INT = 0,
      @n_PartialAllocated INT = 0,
      @c_Company      NVARCHAR(45) = '',
               
      @nSafetyAllocOrders  INT = 0,   
      @nTaskPriority       INT = 0,   
      @nPercentage         DECIMAL(12,3) = 0,  
      @nSafetyPercentage   DECIMAL(12,3) = 0,  
        
      @nPriority       INT = 0,   
      @n_BL_Priority   INT = 9,  
      @n_TotalOrders   INT = 0,
      @d_LastModifiedDate DATETIME       

   DELETE FROM SSRS.AutoAllocStatus
   WHERE EditDate < DATEADD(minute, -10, GETDATE()) 
   
   SELECT TOP 1
         @d_LastModifiedDate = aas.EditDate 
   FROM SSRS.AutoAllocStatus AS aas WITH(NOLOCK)
   ORDER BY aas.EditDate DESC
   
   IF @@ROWCOUNT > 0    
      IF @d_LastModifiedDate IS NOT NULL AND DATEDIFF(minute, @d_LastModifiedDate, GETDATE()) < 5 
         GOTO RETURN_RESULT 
          
   DECLARE @t_Storer TABLE (
   	StorerKey NVARCHAR(15), 
   	Facility NVARCHAR(5), 
   	AllocPriority INT,
     PRIMARY KEY CLUSTERED  (	StorerKey, Facility    )  )
      
   IF @d_LastModifiedDate IS NOT NULL
   BEGIN
      INSERT INTO @t_Storer( StorerKey, Facility, AllocPriority )  
      SELECT blph.StorerKey, blph.Facility, MIN(blph.BL_Priority)   
      FROM V_Backend_Allocate_Parm_Header AS blph WITH(NOLOCK)  
      WHERE BL_BuildType = 'BACKENDALLOC'  
      AND blph.BL_ActiveFlag='1'   
      --AND EXISTS(SELECT 1
      --           FROM PICKDETAIL AS p WITH(NOLOCK) 
      --           JOIN LOC AS l WITH(NOLOCK) ON l.Loc = p.Loc 
      --           WHERE p.Storerkey = blph.StorerKey 
      --           AND L.Facility= blph.Facility
      --           AND P.AddDate > @d_LastModifiedDate )   
      GROUP BY blph.StorerKey, blph.Facility      	
   END      
   ELSE 
   BEGIN
      INSERT INTO @t_Storer( StorerKey, Facility, AllocPriority )  
      SELECT blph.StorerKey, blph.Facility, MIN(blph.BL_Priority)   
      FROM V_Backend_Allocate_Parm_Header AS blph WITH(NOLOCK)  
      WHERE BL_BuildType = 'BACKENDALLOC'  
      AND blph.BL_ActiveFlag='1'   
      GROUP BY blph.StorerKey, blph.Facility     	
   END
   
  
   DECLARE @c_StorerKey NVARCHAR(15),   
           @c_Facility  NVARCHAR(5)  
          
   DECLARE CUR_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT O.StorerKey,   
          S.Company,   
          O.Facility,   
          SUM(CASE WHEN aabd.RowRef IS NOT NULL THEN 1 ELSE 0 END) AS Batched,  
          SUM(CASE WHEN aabd.RowRef IS NULL AND o.[Status] = '0' THEN 1 ELSE 0 END ) AS NotSubmit,   
          SUM(CASE WHEN o.[Status] = '2' THEN 1 ELSE 0 END) AS Allocated,  
          SUM(CASE WHEN o.[Status] = '1' THEN 1 ELSE 0 END) AS PartialAllocated,    
          SUM(CASE WHEN aabd.RowRef IS NOT NULL AND aabd.[Status] = '8' THEN 1 ELSE 0 END) AS NoStock,  
          COUNT(DISTINCT O.OrderKey) AS NoOfOrders, TS.AllocPriority    
   FROM ORDERS O WITH (NOLOCK)   
   JOIN STORER S WITH (NOLOCK) ON O.StorerKey = S.StorerKey    
   LEFT OUTER JOIN AutoAllocBatchDetail AS aabd WITH(NOLOCK) ON aabd.OrderKey = O.OrderKey   
   JOIN @t_Storer TS ON TS.StorerKey = O.StorerKey AND TS.Facility = O.Facility   
   WHERE o.DocType = 'E'  
   AND o.[Status] IN ('0','1','2')  
   AND (o.LoadKey = '' OR o.LoadKey IS NULL)  
   GROUP BY o.StorerKey,   O.Facility, S.Company, TS.AllocPriority 
  
   OPEN CUR_ORDERS  
  
   FETCH NEXT FROM CUR_ORDERS INTO @c_StorerKey, @c_Company, @c_Facility, @n_Batched, @n_NotSubmit, 
            @n_Allocated, @n_PartialAllocated, @n_NoStock, @n_TotalOrders, @n_BL_Priority   
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN        
      SELECT @n_TotalQTask = 0,  
             @n_QTaskWIP   = 0,  
             @n_QTaskError = 0  
     
  
      SELECT @nSafetyAllocOrders = CASE WHEN ISNULL(c.Short, '') = '' AND ISNUMERIC(c.Short) <> 1     
                                        THEN 5000     
                                        ELSE CAST(c.Short as INT)     
                                   END     
          ,@nTaskPriority = CASE WHEN ISNULL(c.long, '') = '' AND ISNUMERIC(c.long) <> 1     
                                        THEN @n_BL_Priority     
                                        ELSE CAST(c.long as INT)     
                                   END      
      FROM CODELKUP AS c WITH(NOLOCK)     
      WHERE c.LISTNAME='AUTOALLOC'    
        AND c.Notes = @c_Facility    
        AND c.Storerkey = @c_StorerKey          
        
      SET @nPercentage = FLOOR( ((@n_Allocated * 1.00) / @n_TotalOrders) * 100)    
        
      IF (@n_Allocated < @nSafetyAllocOrders AND @nSafetyAllocOrders > 0)     
      BEGIN         
        SET @nSafetyPercentage = FLOOR( ((@n_Allocated * 1.00) / @nSafetyAllocOrders) * 100)    
          
        IF @nSafetyPercentage > @nPercentage  
        BEGIN  
           SELECT @nPriority = CASE      
                                 WHEN @nSafetyPercentage BETWEEN  0 AND 25 THEN 1    
                                 WHEN @nSafetyPercentage BETWEEN 26 AND 50 THEN 2    
                                 WHEN @nSafetyPercentage BETWEEN 51 AND 75 THEN 3    
                                 ELSE 4          
                               END             
        END        
        ELSE   
        BEGIN  
           SELECT @nPriority = CASE      
                                 WHEN @nPercentage BETWEEN  0 AND 25 THEN 1    
                                 WHEN @nPercentage BETWEEN 26 AND 50 THEN 2    
                                 WHEN @nPercentage BETWEEN 51 AND 75 THEN 3    
                                 ELSE 4          
                               END             
           
        END          
                                              
      END    
      ELSE IF @nSafetyAllocOrders = 0   
      BEGIN  
        SET @nPriority = @n_BL_Priority   
      END  
      ELSE     
      BEGIN  
         SET @nPriority = 4          
         
         IF @nSafetyAllocOrders > 0 AND @nSafetyAllocOrders >= @n_Allocated  
         BEGIN           	
            SET @nSafetyPercentage = FLOOR( ((@n_Allocated * 1.00) / @nSafetyAllocOrders) * 100)                                                         
         END
         ELSE 
         	SET @nSafetyPercentage = 100  
      END             
                      
    SELECT @n_QTaskWIP   = SUM(CASE WHEN tqt.[Status] = '1' THEN 1 ELSE 0 END),  
           @n_QTaskError = SUM(CASE WHEN tqt.[Status] = '5' THEN 1 ELSE 0 END),   
           @n_TotalQTask = SUM(1)    
    FROM AutoAllocBatchJob AS aabj WITH(NOLOCK)  
    JOIN TCPSocket_QueueTask AS tqt WITH(NOLOCK) ON tqt.TransmitLogKey = aabj.RowID AND tqt.DataStream='BckEndAllo'  
    WHERE aabj.Facility = @c_Facility   
    AND aabj.Storerkey = @c_StorerKey    
    AND aabj.[Status] <= '5'  
    AND aabj.AddDate > DATEADD(hour, -24, GETDATE())  
    
    IF EXISTS(SELECT 1 FROM SSRS.AutoAllocStatus AS aas WITH(NOLOCK)
                  WHERE aas.Storerkey = @c_StorerKey 
                  AND aas.Facility = @c_Facility)     
    BEGIN  
       UPDATE SSRS.AutoAllocStatus  
          SET Batched      = @n_Batched,
    		     NotSubmit    = @n_NotSubmit,
    		     Allocated    = @n_Allocated,
    		     PartialAlloc = @n_PartialAllocated,
    		     NoStock      = @n_NoStock,
    		     TotalOrders  = @n_TotalOrders,        
              TotalQTask = ISNULL(@n_TotalQTask,0),  
              QTaskWIP   = ISNULL(@n_QTaskWIP,0),  
              QTaskError = ISNULL(@n_QTaskError,0),  
              SafetyAllocOrders = ISNULL(@nSafetyAllocOrders,0),   
              SafetyAllocPerctg = ISNULL(@nSafetyPercentage,0),               
              AllocPerctg = ISNULL(@nPercentage,0),  
              AllocPriority = ISNULL(@nPriority,0), 
              EditDate = GETDATE()  
       WHERE Storerkey = @c_StorerKey  
       AND   Facility = @c_Facility   
    END
    ELSE 
    BEGIN
    	INSERT INTO SSRS.AutoAllocStatus
    	(
    		Storerkey,
    		Facility,
    		Company,
    		Batched,
    		NotSubmit,
    		Allocated,
    		PartialAlloc,
    		NoStock,
    		TotalOrders,
    		TotalQTask,
    		QTaskWIP,
    		QTaskError,
    		SafetyAllocOrders,
    		SafetyAllocPerctg,
    		AllocPerctg,
    		AllocPriority 
    	)
    	VALUES
    	(  @c_StorerKey,
    		@c_Facility,
    		@c_Company,
    		@n_Batched,
    		@n_NotSubmit,
    		@n_Allocated,
    		@n_PartialAllocated,
    		@n_NoStock,
    		@n_TotalOrders,
    		ISNULL(@n_TotalQTask,0),
    		ISNULL(@n_QTaskWIP,0),
    		ISNULL(@n_QTaskError,0),
    		ISNULL(@nSafetyAllocOrders,0),
    		ISNULL(@nSafetyPercentage,0),
    		ISNULL(@nPercentage,0),
    		ISNULL(@nPriority,0)  
    	)
    END  
    
      NEXT_RECORD:
      
      FETCH NEXT FROM CUR_ORDERS INTO @c_StorerKey, @c_Company, @c_Facility, @n_Batched, @n_NotSubmit, 
         @n_Allocated, @n_PartialAllocated, @n_NoStock, @n_TotalOrders, @n_BL_Priority   
   END  
   CLOSE CUR_ORDERS  
   DEALLOCATE CUR_ORDERS  
  
   RETURN_RESULT:
   SELECT O.StorerKey ,O.Company ,O.Facility ,O.Batched, O.NotSubmit        
         ,O.Allocated ,O.PartialAlloc ,O.NoStock ,O.TotalOrders ,O.TotalQTask ,O.QTaskWIP       
         ,O.QTaskError, O.SafetyAllocOrders, O.AllocPerctg, O.AllocPriority, O.SafetyAllocPerctg  
   FROM SSRS.AutoAllocStatus O WITH (NOLOCK)   
   UNION ALL   
   SELECT '' AS StorerKey   
         ,'' AS Company        
         ,'' AS Facility       
         ,0  AS Batched        
         ,0  AS NotSubmit        
         ,0  AS Allocated      
         ,0  AS PartialAlloc   
         ,0  AS NoStock        
         ,0  AS TotalOrders    
         ,0  AS TotalQTask     
         ,0  AS QTaskWIP       
         ,0  AS QTaskError   
         ,0  AS SafetyAllocOrders  
         ,0  AS AllocPerctg  
         ,9  AS AllocPriority  
         ,0  AS SafetyAllocPerctg  
   ORDER BY AllocPriority   
     

END

GO