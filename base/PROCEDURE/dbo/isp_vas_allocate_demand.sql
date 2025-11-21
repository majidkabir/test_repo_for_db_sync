SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Stored Proc: isp_VAS_Allocate_Demand                                 */
/* Creation Date: 2018                                                  */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 21-AUG-2018 Wan01    1.0   Fixed Issue.                              */
/* 16-OCT-2018 Wan02    1.1   Do Not reset PlanDate for DemandKey       */
/************************************************************************/

CREATE PROC [dbo].[isp_VAS_Allocate_Demand] (
   @c_HolidayKey NVARCHAR(20) = '', 
   @b_Success INT = 1  OUTPUT ,
   @n_Err     INT = 0  OUTPUT,
   @c_ErrMsg  NVARCHAR(250) = '' OUTPUT , 
   @b_Debug   INT = 0 
   )
AS
BEGIN
   SET NOCOUNT ON
   
   DECLARE @d_SOSDate            DATETIME,
           @d_PlanDate           DATETIME,
           @c_SKU                NVARCHAR(20),
           @c_StorerKey          NVARCHAR(15),
           @c_ProdType           NVARCHAR(10),
           @n_CapacityPerHour        INT = 0, 
           @n_MaxMachineCapacity INT = 0,
           @n_DemandType         NVARCHAR(10) = '',
           @c_Brand              NVARCHAR(15) = '',
           @c_TypePriority       NVARCHAR(10) = '',
           @n_DemandQty          INT = 0,
           @n_TotAllocateQty     INT = 0,
           @n_SeqNo              INT = 0,
           @c_UOM                NVARCHAR(20) = '',
           @n_VASDemandKey       BIGINT,
           @c_KitKey             NVARCHAR(10) = '',
           @c_ComponentSku       NVARCHAR(20) = '', 
           @c_KitQty             INT = 0, 
           @c_PackKey            NVARCHAR(10) = '',
           @c_UOM3               NVARCHAR(10) = '',
           @n_ComponentQty       INT = 0, 
           @n_ParentQty          INT = 0,
           @n_KitQty             INT = 0,
           @n_PlannedQty         INT = 0, 
           @n_RemainingQty       INT = 0,
           @n_TotalPlanDays      INT = 0,
           @n_WorkingHour        INT = 0,
           @n_TodayCapacity      INT = 0,
           @n_TotalHour          INT = 0,
           @n_WorkingMin         INT = 0,             --(Wan02)
           @n_TotalMin           INT = 60,            --(Wan02)
           @n_NoOfDay            INT = 1,             --(Wan02)
           @c_Machineno          NVARCHAR(10) = '',   --(Wan02)
           @c_Machineno_Prev     NVARCHAR(10) = '',   --(Wan02)
           @c_ProdType_Prev      NVARCHAR(10) = '',   --(Wan02)
           @d_DKeyPlanDate       DATETIME             --(Wan02)   
           
   SET @b_Success=1       
   SET @n_Err=0    
   SET @c_ErrMsg=''

   DECLARE CUR_VAS_DEMAND CURSOR LOCAL READ_ONLY READ_ONLY FOR 
   SELECT 
        DEMAND.SOSDate --DATEADD(day, CASE WHEN DEMAND.[Type] = 'On-going' THEN -7 ELSE -14 END, DEMAND.SOSDate ) -- (Wan01)
       ,DEMAND.RepackCode AS SKU 
       ,DEMAND.StorerKey
       ,PROD.Type
       ,ISNULL(PROD.Productivity 
               * CASE WHEN ISNUMERIC(ISNULL(VASMP.Short,'')) = 1 THEN CAST(VASMP.Short AS INT) ELSE 0 END 
               --* (1+CONVERT(FLOAT, ISNULL(CLK.Short,0))/100)
               , 0) 
               AS CapacityPerHour
       ,ISNULL(CASE 
               WHEN PROD.Type='MACHINE' THEN PROD.MaxCapacity * PROD.MachineQty
               END, 0) AS MAXMachineCapacity
       ,DEMAND.[Type]
       ,CASE WHEN DEMAND.[Type] = 'PROMOTION' AND PROD.[Type] = 'MACHINE' THEN 1 
             WHEN DEMAND.[Type] = 'PROMOTION' THEN 3
             WHEN DEMAND.[Type] = 'ON-GOING'  THEN 5
             ELSE 9
        END AS TypePriority
       ,DEMAND.Qty 
       ,DEMAND.Brand 
       ,DEMAND.UOM
       ,DEMAND.VASDemandKey
       ,CASE WHEN DEMAND.[Type] = 'ON-GOING' THEN 7 ELSE 16 END AS TotalPlanDays
       ,CASE WHEN ISNUMERIC(ISNULL(VASMP.UDF01,'')) = 1 THEN CAST(VASMP.UDF01 AS INT) ELSE 0 END AS WorkingHour
       ,MachineNo = CASE WHEN PROD.Type = 'MACHINE' THEN MachineNo ELSE '' END                                                --(Wan02)
   FROM  dbo.VAS_Demand DEMAND  (NOLOCK)  
   INNER JOIN dbo.VAS_Productivity PROD (NOLOCK) ON  DEMAND.RepackCode = PROD.SKU
                   AND DEMAND.StorerKey = PROD.StorerKey 
   LEFT OUTER JOIN dbo.Codelkup CLK (NOLOCK)
               ON  CLK.Listname = 'VASPRODUCT'
                   AND PROD.Storerkey = CLK.StorerKey
   LEFT OUTER JOIN dbo.Codelkup VASMP (NOLOCK)
               ON  VASMP.Listname = 'VASMP'
                   AND PROD.Storerkey = VASMP.StorerKey                   
   WHERE DEMAND.Status='OPEN'  
   AND DEMAND.SOSDate BETWEEN DATEADD(DAY, 2, GETDATE()) AND DATEADD(DAY, CASE WHEN DEMAND.[Type] = 'ON-GOING' THEN 8 ELSE 18 END , GETDATE()) 
   ORDER BY PROD.Type, MachineNo, TypePriority, SOSDate, DEMAND.Priority, MAXMachineCapacity                                 --(Wan02)  

   OPEN CUR_VAS_DEMAND

   FETCH NEXT FROM CUR_VAS_DEMAND INTO @d_SOSDate, @c_SKU, @c_StorerKey, @c_ProdType, @n_CapacityPerHour, @n_MaxMachineCapacity, 
         @n_DemandType,@c_TypePriority, @n_DemandQty, @c_Brand, @c_UOM ,@n_VASDemandKey, @n_TotalPlanDays, @n_WorkingHour, @c_MachineNo
    WHILE @@FETCH_STATUS=0
   BEGIN
      SET @n_WorkingMin = @n_WorkingHour * 60

      --(Wan02) - START
      IF @c_ProdType <> @c_ProdType_Prev OR  @c_MachineNo <> @c_MachineNo_Prev
      BEGIN
         SET @n_NoOfDay  = 1
         SET @n_TotalMin = 0
      END
      --(Wan02) - END

      IF @b_Debug = 1
      BEGIN
         PRINT ''
         PRINT '---------------------------------'
         PRINT '@n_VASDemandKey: ' + CAST(@n_VASDemandKey AS VARCHAR) + ' SKU: ' + @c_SKU 
         PRINT '@n_DemandType: ' + @n_DemandType 
      END
      
      SET @n_TotAllocateQty = 0
      SET @n_SeqNo = 1
         
      SELECT @n_TotAllocateQty = ISNULL(SUM(vp.AllocatedQty),0),
             @n_SeqNo = MAX(vp.SeqNo),
             @d_DKeyPlanDate = MAX(vp.PlanDate) 
      FROM VAS_Plan AS vp WITH(NOLOCK)
      WHERE vp.VASDemandKey = @n_VASDemandKey      
       
      SET @n_SeqNo = ISNULL(@n_SeqNo, 1)

      --(Wan02) - START
      IF @n_NoOfDay = 1 AND @n_TotalMin = 0
      BEGIN
         SET @d_PlanDate = ISNULL(@d_DKeyPlanDate, DATEADD(day, -1 * @n_TotalPlanDays, @d_SOSDate)) -- (Wan01)
      END
      --(Wan02) - END
      
      IF @b_Debug=1
      BEGIN
         PRINT 'TotAllocateQty: ' + CAST(@n_TotAllocateQty AS VARCHAR) + ' @n_DemandQty: ' + CAST(@n_DemandQty AS VARCHAR) 
         PRINT 'PlanDate: ' + CAST(@d_PlanDate AS VARCHAR)  
         PRINT '@n_NoOfDay: ' + CAST(@n_NoOfDay AS VARCHAR)
         PRINT '@n_TotalMin: ' + CAST (@n_TotalMin AS VARCHAR)
      END
      
      IF @n_TotAllocateQty >= @n_DemandQty OR @n_SeqNo = @n_TotalPlanDays 
         GOTO FETCH_NEXT
      
      SET @n_RemainingQty = @n_DemandQty - @n_TotAllocateQty 

      -- schecdule for 7 days
      WHILE @n_NoOfDay <= @n_TotalPlanDays AND @n_RemainingQty > 0
      BEGIN
         PRINT 'SeqNo: ' + CAST(@n_SeqNo AS VARCHAR)
         
         -- if fall under weekend or public holiday, no work plan allow
         IF DATENAME(DW, @d_PlanDate) IN ('Saturday','Sunday') OR 
            EXISTS(SELECT 1 FROM HolidayDetail AS hd WITH(NOLOCK) 
                   WHERE hd.HolidayKey  = @c_HolidayKey 
                   AND   hd.HolidayDate = @d_PlanDate 
                   AND   @c_HolidayKey <> '')
         BEGIN
            PRINT 'SKIP Weekend/Holiday'
            GOTO NEXT_DAY
         END
         ELSE
         BEGIN
            SET @n_PlannedQty = 0            

            IF @c_ProdType = 'MACHINE'
            BEGIN
               IF @n_RemainingQty <= @n_MaxMachineCapacity
               BEGIN
                  SET @n_PlannedQty = @n_RemainingQty
               END                  
               ELSE
               BEGIN
                  SET @n_PlannedQty = @n_MaxMachineCapacity 
               END

               --(Wan02) - START
               IF @n_PlannedQty > (@n_MaxMachineCapacity - @n_TodayCapacity) AND @n_TodayCapacity > 0
               BEGIN
                  SET @n_PlannedQty = @n_MaxMachineCapacity - @n_TodayCapacity
               END

               SET @n_TodayCapacity = @n_TodayCapacity + @n_PlannedQty

               IF @b_Debug=1
               BEGIN
                  PRINT '@n_TodayCapacity: ' + + CAST(@n_TodayCapacity AS VARCHAR)
               END

               IF @n_TodayCapacity = @n_MaxMachineCapacity
               BEGIN
                  SET @n_TotalMin = @n_WorkingMin + 60            -- To Reset TotalMin and increase Plandate
                  SET @n_TodayCapacity = 0
               END
               --(Wan02) - END
            END
            ELSE 
            BEGIN
               IF @n_RemainingQty <= @n_CapacityPerHour
               BEGIN
                  SET @n_PlannedQty = @n_RemainingQty
               END                  
               ELSE
               BEGIN
                  SET @n_PlannedQty = @n_CapacityPerHour
               END
            END

            IF @b_Debug=1
            BEGIN
               PRINT '@n_CapacityPerHour: ' + CAST(@n_CapacityPerHour AS VARCHAR)
               PRINT '@n_PlannedQty: ' + CAST(@n_PlannedQty AS VARCHAR)
               PRINT 'PlanDate: ' + CAST(@d_PlanDate AS VARCHAR)  
            END  
            
            IF @n_PlannedQty > 0
            BEGIN
               SET @n_TotalMin = @n_TotalMin + CEILING((@n_PlannedQty * 1.00 / @n_CapacityPerHour) * 60) --(Wan02)  

               IF @b_Debug=1
               BEGIN

                  PRINT '@n_TotalMin: '+ CAST(@n_TotalMin AS VARCHAR)
               END                     

               INSERT INTO VAS_Plan
               (  StorerKey,     Brand,            [Type],
                  SeqNo,         RepackCode,       SOSDate,
                  PlanDate,      DemandQty,        AllocatedQty,
                  UOM,           KITKey,           VASDemandKey )
               VALUES
               (  @c_StorerKey,  @c_Brand,      @n_DemandType,
                  @n_SeqNo,      @c_SKU,        @d_SOSDate,
                  @d_PlanDate,   @n_DemandQty,  @n_PlannedQty,
                  @c_UOM,        '',            @n_VASDemandKey)     
         
               SET @n_RemainingQty = @n_RemainingQty - @n_PlannedQty             
            END
            
            IF @b_Debug=1
            BEGIN
               PRINT '@n_PlannedQty: ' + CAST(@n_PlannedQty AS VARCHAR) + ' @n_RemainingQty: ' + CAST(@n_RemainingQty AS VARCHAR)
            END
            --(Wan02) - START
            IF @n_TotalMin > @n_WorkingMin 
            BEGIN
               SET @n_NoOfDay  = @n_NoOfDay + 1
               SET @n_TotalMin = 0 
            END

            --IF @n_RemainingQty = 0 
            --   BREAK 
            --(Wan02) - END               
         END   
         
         NEXT_DAY:
         
         SET @n_SeqNo = @n_SeqNo + 1
         --(Wan02) - START
         IF @n_TotalMin = 0 
         BEGIN
            SET @d_PlanDate = DATEADD(DAY, 1, @d_PlanDate)
         END 
         --(Wan02) - END                    
      END -- WHILE @n_SeqNo < @n_TotalPlanDays AND @n_RemainingQty > 0
             
      UPDATE VAS_Demand SET STATUS='Planning' WHERE VASDemandKey=@n_VASDemandKey
                         
      FETCH_NEXT:
      SET @c_MachineNo_Prev = @c_MachineNo                                                                                                                  --(Wan02)
      SET @c_ProdType_Prev  = @c_ProdType                                                                                                                   --(Wan02)   
      FETCH NEXT FROM CUR_VAS_DEMAND INTO @d_SOSDate, @c_SKU, @c_StorerKey, @c_ProdType, @n_CapacityPerHour, 
               @n_MaxMachineCapacity, @n_DemandType, @c_TypePriority, @n_DemandQty, @c_Brand, @c_UOM  ,@n_VASDemandKey, @n_TotalPlanDays, @n_WorkingHour,
               @c_MachineNo                                                                                                                                 --(Wan02)
   END 
   CLOSE CUR_VAS_DEMAND
   DEALLOCATE CUR_VAS_DEMAND
   
END -- Procedure 

GO