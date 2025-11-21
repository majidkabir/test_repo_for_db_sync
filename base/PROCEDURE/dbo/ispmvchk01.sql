SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispMVCHK01                                         */
/* Creation Date: 16-OCT-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-10923 Not allow WMS move if the pallet have pending     */
/*          putaway task for RDT.                                       */
/*                                                                      */
/* Called By: Inventory Move                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 11-Jun-2020  NJOW01   1.0  WMS-13698 not allow inventory move        */
/*                            if pendingmovein                          */
/* 18-Jun-2020  NJOW02   1.1  Fix to include fitler id and locationtype */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMVCHK01]
   @c_Lot       NVARCHAR(10),
   @c_FromLoc   NVARCHAR(10), 
   @c_FromID    NVARCHAR(18), 
   @b_Success   INT = 1  OUTPUT,
   @n_Err       INT = 0  OUTPUT,
   @c_Errmsg    NVARCHAR(250) = '' OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_Storerkey NVARCHAR(15),
           @c_Taskdetailkey NVARCHAR(10),
           @n_Continue INT,           
           @n_IsRDT INT,
           @c_Facility NVARCHAR(5)
   
   SELECT @b_Success = 1, @n_Err = 0, @c_Errmsg = '', @n_Continue = 1, @c_Storerkey = '', @c_Taskdetailkey = ''
   
   IF ISNULL(@c_Lot,'') <> ''
   BEGIN
   	  SELECT @c_Storerkey = Storerkey
   	  FROM LOT (NOLOCK)
   	  WHERE Lot = @c_Lot   	        	  
   END
   ELSE
      SET @c_Storerkey = ''
   
   --NJOW01   
   SELECT @c_Facility = Facility
   FROM LOC (NOLOCK)
   WHERE Loc = @c_FromLoc      
   
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT 
 
   IF @n_IsRDT <> 1 
   BEGIN   	   	
   	  SELECT TOP 1 @c_Taskdetailkey = Taskdetailkey 
   	  FROM TASKDETAIL (NOLOCK)
   	  WHERE TaskType = 'PA1'
   	  AND FromLoc = @c_FromLoc
   	  AND FromID = @c_FromID
   	  AND Status =  '0'
   	  AND LEFT(SourceType,4) = 'rdt_' 
   	  AND (Storerkey = @c_Storerkey OR @c_Storerkey = '')

      IF ISNULL(@c_Taskdetailkey,'') <> ''   
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_Err = 7590
         SELECT @c_errmsg = 'Not allow to move pallet with pending putaway task. From Loc: ' + RTRIM(@c_FromLoc) + ' From ID: ' + RTRIM(@c_FromID) + ' Task#: ' + RTRIM(@c_Taskdetailkey) + ' (ispMVCHK01)' 
         SELECT @b_Success = 0
         GOTO EXIT_SP   	
      END

      --NJOW01
      IF EXISTS ( SELECT 1 
                  FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                  WHERE LLI.StorerKey = @c_StorerKey
                  AND   LLI.ID = @c_FromID
                  AND   LOC.Facility = @c_Facility
                  AND   ISNULL(@c_FromID,'') <> '' --NJOW01                                
                  GROUP BY LLI.ID
                  HAVING ISNULL( SUM( LLI.PendingMoveIn), 0) > 0)
         AND NOT EXISTS(SELECT 1 FROM LOC(NOLOCK)  --NJOW01
                        WHERE LOC.Loc = @c_FromLoc 
                        AND LOC.LocationType IN('PICK','CASE'))         
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_Err = 7595
         SELECT @c_errmsg = 'Not allow to move pallet with pending putaway Qty. From Loc: ' + RTRIM(@c_FromLoc) + ' From ID: ' + RTRIM(@c_FromID) + ' (ispMVCHK01)' 
         SELECT @b_Success = 0
         GOTO EXIT_SP   	
      END      
   END   
        
   EXIT_SP:  
END


GO